# COMPREHENSIVE OPENPROJECT MCP SERVER FOR NS POWER T&D WORKPLANS
# Enhanced with ID resolution, connection pooling, and extensive tools

import asyncio
import asyncpg
import os
import json
from datetime import datetime, timedelta, date
from typing import Optional, List, Dict, Any, Union
from fastmcp import FastMCP
from decimal import Decimal

# Database configuration from environment variables
DB_HOST = os.getenv('DB_HOST', '192.168.3.78')
DB_PORT = int(os.getenv('DB_PORT', '5432'))
DB_NAME = os.getenv('DB_NAME', 'openproject')
DB_USER = os.getenv('DB_USER', 'openproject')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'openproject')

# Initialize FastMCP
mcp = FastMCP("OpenProject T&D Workplan Assistant")

# Connection pool for better performance
db_pool: Optional[asyncpg.Pool] = None

async def get_db_pool():
    """Get or create database connection pool"""
    global db_pool
    if db_pool is None:
        db_pool = await asyncpg.create_pool(
        host=DB_HOST,
        port=DB_PORT,
        database=DB_NAME,
        user=DB_USER,
            password=DB_PASSWORD,
            min_size=2,
            max_size=10,
            command_timeout=60
    )
    return db_pool

# ============================================================================
# HELPER FUNCTIONS FOR ID RESOLUTION AND DATA FORMATTING
# ============================================================================

def serialize_value(value):
    """Convert database values to JSON-serializable format"""
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    elif isinstance(value, Decimal):
        return float(value)
    elif isinstance(value, timedelta):
        return str(value)
    elif value is None:
        return None
    else:
        return value

def dictify_row(row):
    """Convert asyncpg Record to dictionary with serialized values"""
    if row is None:
        return None
    return {key: serialize_value(value) for key, value in dict(row).items()}

def dictify_rows(rows):
    """Convert list of asyncpg Records to list of dictionaries"""
    return [dictify_row(row) for row in rows]

async def resolve_user_ids(conn, user_ids: List[int]) -> Dict[int, Dict]:
    """Resolve user IDs to actual user information"""
    if not user_ids or not any(user_ids):
        return {}
    
    valid_ids = [id for id in user_ids if id is not None]
    if not valid_ids:
        return {}
    
    result = await conn.fetch("""
        SELECT id, login, firstname, lastname, mail, status
        FROM users
        WHERE id = ANY($1::bigint[])
    """, valid_ids)
    
    return {
        row['id']: {
            'login': row['login'],
            'name': f"{row['firstname']} {row['lastname']}".strip(),
            'email': row['mail'],
            'status': row['status']
        }
        for row in result
    }

async def resolve_status_ids(conn, status_ids: List[int]) -> Dict[int, Dict]:
    """Resolve status IDs to actual status information"""
    if not status_ids or not any(status_ids):
        return {}
    
    valid_ids = [id for id in status_ids if id is not None]
    if not valid_ids:
        return {}
    
    result = await conn.fetch("""
        SELECT id, name, is_closed, is_default, position, default_done_ratio
        FROM statuses
        WHERE id = ANY($1::bigint[])
    """, valid_ids)
    
    return {
        row['id']: {
            'name': row['name'],
            'is_closed': row['is_closed'],
            'is_default': row['is_default'],
            'position': row['position'],
            'done_ratio': row['default_done_ratio']
        }
        for row in result
    }

async def resolve_type_ids(conn, type_ids: List[int]) -> Dict[int, Dict]:
    """Resolve type IDs to actual type information"""
    if not type_ids or not any(type_ids):
        return {}
    
    valid_ids = [id for id in type_ids if id is not None]
    if not valid_ids:
        return {}
    
    result = await conn.fetch("""
        SELECT id, name, is_milestone, is_in_roadmap, position
        FROM types
        WHERE id = ANY($1::bigint[])
    """, valid_ids)
    
    return {
        row['id']: {
            'name': row['name'],
            'is_milestone': row['is_milestone'],
            'is_in_roadmap': row['is_in_roadmap'],
            'position': row['position']
        }
        for row in result
    }

async def resolve_priority_ids(conn, priority_ids: List[int]) -> Dict[int, str]:
    """Resolve priority IDs to actual priority names"""
    if not priority_ids or not any(priority_ids):
        return {}
    
    valid_ids = [id for id in priority_ids if id is not None]
    if not valid_ids:
        return {}
    
    result = await conn.fetch("""
        SELECT id, name
        FROM enumerations
        WHERE id = ANY($1::bigint[]) AND type = 'IssuePriority'
    """, valid_ids)
    
    return {row['id']: row['name'] for row in result}

async def resolve_project_ids(conn, project_ids: List[int]) -> Dict[int, Dict]:
    """Resolve project IDs to actual project information"""
    if not project_ids or not any(project_ids):
        return {}
    
    valid_ids = [id for id in project_ids if id is not None]
    if not valid_ids:
        return {}
    
    result = await conn.fetch("""
        SELECT id, name, identifier, status_code, parent_id, description
        FROM projects
        WHERE id = ANY($1::bigint[])
    """, valid_ids)
    
    return {
        row['id']: {
            'name': row['name'],
            'identifier': row['identifier'],
            'status_code': row['status_code'],
            'parent_id': row['parent_id'],
            'description': row['description']
        }
        for row in result
    }

def get_project_status_name(status_code: int) -> str:
    """Convert project status code to human-readable name"""
    status_map = {
        0: 'Initiated',
        1: 'In Planning', 
        2: 'Active',
        3: 'On Hold',
        4: 'Completed',
        5: 'Cancelled',
        6: 'At Risk'
    }
    return status_map.get(status_code, 'Unknown')

# ============================================================================
# 1. PROJECT OVERVIEW & STATUS TOOLS
# ============================================================================

@mcp.tool()
async def get_project_overview(project_name: Optional[str] = None):
    """Get comprehensive project overview including status, timeline, and key metrics"""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        where_clause = ""
        params = []
        
        if project_name:
            where_clause = "WHERE (p.name ILIKE $1 OR p.identifier ILIKE $1) AND p.active = true"
            params = [f'%{project_name}%']
        else:
            where_clause = "WHERE p.active = true"
        
        projects = await conn.fetch(f"""
            WITH project_stats AS (
            SELECT 
                    p.id,
                p.name,
                    p.identifier,
                p.description,
                    p.status_code,
                    p.parent_id,
                    p.created_at,
                    p.updated_at,
                    COUNT(DISTINCT wp.id) as total_work_packages,
                    COUNT(DISTINCT CASE WHEN s.is_closed = true THEN wp.id END) as completed_tasks,
                    COUNT(DISTINCT CASE WHEN wp.due_date < CURRENT_DATE AND s.is_closed = false THEN wp.id END) as overdue_tasks,
                    COUNT(DISTINCT CASE WHEN wp.assigned_to_id IS NULL AND s.is_closed = false THEN wp.id END) as unassigned_tasks,
                    MIN(wp.start_date) as earliest_start,
                    MAX(wp.due_date) as latest_due,
                AVG(wp.done_ratio) as avg_completion,
                    COUNT(DISTINCT wp.assigned_to_id) as team_size
            FROM projects p
                LEFT JOIN work_packages wp ON wp.project_id = p.id
                LEFT JOIN statuses s ON s.id = wp.status_id
            {where_clause}
                GROUP BY p.id
            )
            SELECT * FROM project_stats
            ORDER BY name
        """, *params)
        
        # Resolve parent project IDs
        parent_ids = [p['parent_id'] for p in projects if p['parent_id']]
        parent_projects = await resolve_project_ids(conn, parent_ids) if parent_ids else {}
        
        results = []
        for proj in projects:
            results.append({
                'id': proj['id'],
                'name': proj['name'],
                'identifier': proj['identifier'],
                'description': proj['description'],
                'status': get_project_status_name(proj['status_code']) if proj['status_code'] else 'Unknown',
                'parent_project': parent_projects.get(proj['parent_id'], {}).get('name') if proj['parent_id'] else None,
                'created_at': serialize_value(proj['created_at']),
                'updated_at': serialize_value(proj['updated_at']),
                'metrics': {
                    'total_tasks': proj['total_work_packages'],
                    'completed_tasks': proj['completed_tasks'],
                    'overdue_tasks': proj['overdue_tasks'],
                    'unassigned_tasks': proj['unassigned_tasks'],
                    'completion_percentage': float(proj['avg_completion']) if proj['avg_completion'] else 0,
                    'team_size': proj['team_size'],
                    'timeline': {
                        'start': serialize_value(proj['earliest_start']),
                        'end': serialize_value(proj['latest_due'])
                    }
                }
            })
        
        return results

@mcp.tool()
async def get_project_hierarchy():
    """Get complete project hierarchy showing parent-child relationships"""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        result = await conn.fetch("""
            WITH RECURSIVE project_tree AS (
                SELECT 
                    id, name, identifier, parent_id, status_code,
                    0 as level,
                    ARRAY[id] as path,
                    name::text as full_path
                FROM projects
                WHERE parent_id IS NULL AND active = true
                
                UNION ALL
                
                SELECT 
                    p.id, p.name, p.identifier, p.parent_id, p.status_code,
                    pt.level + 1,
                    pt.path || p.id,
                    pt.full_path || ' > ' || p.name
                FROM projects p
                INNER JOIN project_tree pt ON p.parent_id = pt.id
                WHERE p.active = true
            )
            SELECT 
                id, name, identifier, parent_id, 
                status_code,
                level, full_path
            FROM project_tree
            ORDER BY path
        """)
        
        return dictify_rows(result)

@mcp.tool()
async def get_project_health_report(project_name: Optional[str] = None):
    """Generate comprehensive project health analysis"""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        conditions = ["p.active = true"]
        params = []
        
        if project_name:
            conditions.append("(p.name ILIKE $1 OR p.identifier ILIKE $1)")
            params.append(f'%{project_name}%')
        
        where_clause = " AND ".join(conditions)
        
        result = await conn.fetch(f"""
            SELECT
                p.name as project_name,
                p.identifier,
                p.status_code,
                COUNT(wp.id) as total_work_packages,
                COUNT(CASE WHEN s.is_closed = true THEN 1 END) as completed_packages,
                COUNT(CASE WHEN wp.done_ratio = 0 THEN 1 END) as not_started_packages,
                COUNT(CASE WHEN wp.due_date < CURRENT_DATE AND s.is_closed = false THEN 1 END) as overdue_packages,
                COUNT(CASE WHEN wp.due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'
                      AND s.is_closed = false THEN 1 END) as due_this_week,
                AVG(wp.done_ratio) as avg_completion_rate,
                COUNT(DISTINCT wp.assigned_to_id) as team_size,
                SUM(wp.estimated_hours) as total_estimated_hours,
                MIN(wp.start_date) as earliest_start_date,
                MAX(wp.due_date) as latest_due_date,
                COUNT(CASE WHEN wp.start_date IS NULL THEN 1 END) as packages_without_start_date,
                COUNT(CASE WHEN wp.due_date IS NULL THEN 1 END) as packages_without_due_date,
                MAX(wp.updated_at) as last_activity,
                COUNT(CASE WHEN wp.updated_at >= CURRENT_DATE - INTERVAL '7 days' THEN 1 END) as active_this_week,
                CASE
                    WHEN COUNT(CASE WHEN wp.due_date < CURRENT_DATE AND s.is_closed = false THEN 1 END) > 0 THEN 'High Risk'
                    WHEN AVG(wp.done_ratio) < 50 AND MAX(wp.due_date) < CURRENT_DATE + INTERVAL '30 days' THEN 'Medium Risk'
                    WHEN COUNT(CASE WHEN wp.updated_at >= CURRENT_DATE - INTERVAL '14 days' THEN 1 END) = 0 THEN 'Stale'
                    ELSE 'Healthy'
                END as health_status
            FROM projects p
            LEFT JOIN work_packages wp ON p.id = wp.project_id
            LEFT JOIN statuses s ON s.id = wp.status_id
            WHERE {where_clause}
            GROUP BY p.id, p.name, p.identifier, p.status_code
            ORDER BY p.name
        """, *params)
        
        return dictify_rows(result)

# ============================================================================
# 2. WORK PACKAGE & TASK MANAGEMENT TOOLS
# ============================================================================

@mcp.tool()
async def search_work_packages(
    query: Optional[str] = None,
    project_name: Optional[str] = None,
    status: Optional[str] = None,
    assignee: Optional[str] = None,
    type_name: Optional[str] = None,
    priority: Optional[str] = None,
    limit: int = 50
):
    """Advanced work package search with multiple filters and resolved IDs"""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        conditions = ["1=1"]
        params = []
        param_count = 0
        
        if query:
            param_count += 1
            conditions.append(f"(wp.subject ILIKE ${param_count} OR wp.description ILIKE ${param_count})")
            params.append(f'%{query}%')
        
        if project_name:
            param_count += 1
            conditions.append(f"(p.name ILIKE ${param_count} OR p.identifier ILIKE ${param_count})")
            params.append(f'%{project_name}%')
            
        if status:
            param_count += 1
            conditions.append(f"s.name ILIKE ${param_count}")
            params.append(f'%{status}%')
            
        if assignee:
            param_count += 1
            conditions.append(f"(u_assigned.firstname || ' ' || u_assigned.lastname) ILIKE ${param_count}")
            params.append(f'%{assignee}%')
            
        if type_name:
            param_count += 1
            conditions.append(f"t.name ILIKE ${param_count}")
            params.append(f'%{type_name}%')
            
        if priority:
            param_count += 1
            conditions.append(f"e.name ILIKE ${param_count}")
            params.append(f'%{priority}%')
        
        where_clause = " AND ".join(conditions)
        
        result = await conn.fetch(f"""
            SELECT 
                wp.id,
                wp.subject,
                wp.description,
                wp.start_date,
                wp.due_date,
                wp.done_ratio,
                wp.estimated_hours,
                wp.remaining_hours,
                wp.created_at,
                wp.updated_at,
                p.name as project_name,
                p.identifier as project_identifier,
                s.name as status_name,
                s.is_closed,
                t.name as type_name,
                t.is_milestone,
                e.name as priority_name,
                u_assigned.firstname || ' ' || u_assigned.lastname as assigned_to_name,
                u_author.firstname || ' ' || u_author.lastname as author_name,
                CASE 
                    WHEN wp.due_date < CURRENT_DATE AND s.is_closed = false THEN 'overdue'
                    WHEN wp.due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 7 THEN 'due_soon'
                    ELSE 'on_track'
                END as urgency
            FROM work_packages wp
            LEFT JOIN projects p ON p.id = wp.project_id
            LEFT JOIN statuses s ON s.id = wp.status_id
            LEFT JOIN types t ON t.id = wp.type_id
            LEFT JOIN enumerations e ON e.id = wp.priority_id
            LEFT JOIN users u_assigned ON u_assigned.id = wp.assigned_to_id
            LEFT JOIN users u_author ON u_author.id = wp.author_id
            WHERE {where_clause}
            ORDER BY wp.updated_at DESC
            LIMIT {limit}
        """, *params)
        
        return dictify_rows(result)

@mcp.tool()
async def get_work_package_timeline(project_name: Optional[str] = None, days_ahead: int = 30):
    """Get timeline view of work packages with due dates and milestones"""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        end_date = datetime.now() + timedelta(days=days_ahead)
        
        conditions = ["wp.due_date IS NOT NULL", "wp.due_date <= $1"]
        params = [end_date]
        
        if project_name:
            conditions.append("(p.name ILIKE $2 OR p.identifier ILIKE $2)")
            params.append(f'%{project_name}%')
        
        where_clause = " AND ".join(conditions)
        
        result = await conn.fetch(f"""
            SELECT 
                wp.id,
                wp.subject,
                wp.start_date,
                wp.due_date,
                wp.done_ratio,
                p.name as project_name,
                t.name as type_name,
                t.is_milestone,
                s.name as status_name,
                s.is_closed,
                u.firstname || ' ' || u.lastname as assigned_to,
                CASE 
                    WHEN wp.due_date < CURRENT_DATE AND s.is_closed = false THEN 'overdue'
                    WHEN wp.due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + interval '7 days' THEN 'due_soon'
                    ELSE 'on_track'
                END as urgency,
                wp.due_date - CURRENT_DATE as days_until_due
            FROM work_packages wp
            JOIN projects p ON p.id = wp.project_id
            LEFT JOIN types t ON t.id = wp.type_id
            LEFT JOIN statuses s ON s.id = wp.status_id
            LEFT JOIN users u ON u.id = wp.assigned_to_id
            WHERE {where_clause}
            ORDER BY wp.due_date ASC, t.is_milestone DESC
        """, *params)
        
        return dictify_rows(result)

@mcp.tool()
async def get_work_package_dependencies(work_package_id: Optional[int] = None, project_name: Optional[str] = None):
    """Get work package dependencies and blocking relationships"""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        if work_package_id:
            result = await conn.fetch("""
                SELECT 
                    r.id as relation_id,
                    r.relation_type,
                    r.delay,
                    wp_from.id as from_id,
                    wp_from.subject as from_subject,
                    wp_to.id as to_id,
                    wp_to.subject as to_subject,
                    s_from.name as from_status,
                    s_to.name as to_status,
                    p_from.name as from_project,
                    p_to.name as to_project
                FROM relations r
                JOIN work_packages wp_from ON wp_from.id = r.from_id
                JOIN work_packages wp_to ON wp_to.id = r.to_id
                LEFT JOIN projects p_from ON p_from.id = wp_from.project_id
                LEFT JOIN projects p_to ON p_to.id = wp_to.project_id
                LEFT JOIN statuses s_from ON s_from.id = wp_from.status_id
                LEFT JOIN statuses s_to ON s_to.id = wp_to.status_id
                WHERE r.from_id = $1 OR r.to_id = $1
                ORDER BY r.relation_type
            """, work_package_id)
        else:
            conditions = ["r.relation_type = 'blocks'"]
            params = []
            
            if project_name:
                conditions.append("(p_from.name ILIKE $1 OR p_to.name ILIKE $1)")
                params.append(f'%{project_name}%')
            
            where_clause = " AND ".join(conditions)
            
            result = await conn.fetch(f"""
                SELECT 
                    r.id as relation_id,
                    r.relation_type,
                    wp_from.subject as blocking_task,
                    wp_to.subject as blocked_task,
                    p_from.name as blocking_project,
                    p_to.name as blocked_project,
                    s_from.name as blocking_status,
                    s_to.name as blocked_status,
                    s_from.is_closed as blocker_closed
                FROM relations r
                JOIN work_packages wp_from ON wp_from.id = r.from_id
                JOIN work_packages wp_to ON wp_to.id = r.to_id
                JOIN projects p_from ON p_from.id = wp_from.project_id
                JOIN projects p_to ON p_to.id = wp_to.project_id
                LEFT JOIN statuses s_from ON s_from.id = wp_from.status_id
                LEFT JOIN statuses s_to ON s_to.id = wp_to.status_id
                WHERE {where_clause}
                ORDER BY s_from.is_closed ASC, wp_from.due_date ASC
            """, *params)
        
        return dictify_rows(result)

# ============================================================================
# 3. RESOURCE & CAPACITY MANAGEMENT TOOLS
# ============================================================================

@mcp.tool()
async def get_user_workload(username: Optional[str] = None, include_completed: bool = False):
    """Get detailed workload analysis for users"""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        user_condition = ""
        params = []
        
        if username:
            user_condition = "WHERE u.login ILIKE $1 OR (u.firstname || ' ' || u.lastname) ILIKE $1"
            params = [f'%{username}%']
        
        status_filter = "" if include_completed else "AND s.is_closed = false"
        
        result = await conn.fetch(f"""
            WITH user_workload AS (
            SELECT 
                    u.id,
                    u.firstname || ' ' || u.lastname as name,
                u.mail as email,
                    COUNT(DISTINCT wp.id) as total_tasks,
                    COUNT(DISTINCT CASE WHEN wp.due_date < CURRENT_DATE THEN wp.id END) as overdue_tasks,
                    COUNT(DISTINCT CASE WHEN wp.due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 7 THEN wp.id END) as due_this_week,
                    COUNT(DISTINCT CASE WHEN wp.due_date BETWEEN CURRENT_DATE + 8 AND CURRENT_DATE + 30 THEN wp.id END) as due_this_month,
                SUM(wp.estimated_hours) as total_estimated_hours,
                    SUM(wp.remaining_hours) as total_remaining_hours,
                    AVG(wp.done_ratio) as avg_completion,
                    COUNT(DISTINCT wp.project_id) as project_count,
                MAX(wp.updated_at) as last_activity
            FROM users u
                LEFT JOIN work_packages wp ON wp.assigned_to_id = u.id
                LEFT JOIN statuses s ON s.id = wp.status_id
                {user_condition}
                {status_filter}
                GROUP BY u.id, u.firstname, u.lastname, u.mail
                HAVING COUNT(DISTINCT wp.id) > 0
            )
            SELECT * FROM user_workload
            ORDER BY total_tasks DESC, name
        """, *params)
        
        return dictify_rows(result)

@mcp.tool()
async def get_team_performance(project_name: Optional[str] = None, days_back: int = 30):
    """Analyze team performance metrics over specified time period"""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        start_date = datetime.now() - timedelta(days=days_back)
        
        conditions = [f"wp.updated_at >= $1"]
        params = [start_date]
        
        if project_name:
            conditions.append("(p.name ILIKE $2 OR p.identifier ILIKE $2)")
            params.append(f'%{project_name}%')
        
        where_clause = " AND ".join(conditions)
        
        result = await conn.fetch(f"""
            SELECT 
                p.name as project_name,
                u.firstname || ' ' || u.lastname as team_member,
                COUNT(wp.id) as tasks_worked_on,
                COUNT(CASE WHEN s.is_closed = true THEN 1 END) as tasks_completed,
                AVG(wp.done_ratio) as avg_progress,
                COUNT(CASE WHEN wp.due_date < CURRENT_DATE AND s.is_closed = false THEN 1 END) as overdue_count,
                COUNT(CASE WHEN wp.created_at >= $1 THEN 1 END) as tasks_created_recently,
                COUNT(CASE WHEN wp.updated_at >= CURRENT_DATE - INTERVAL '7 days' THEN 1 END) as tasks_updated_this_week,
                AVG(CASE WHEN s.is_closed = true AND wp.due_date IS NOT NULL 
                    THEN EXTRACT(days FROM wp.updated_at - wp.due_date) END) as avg_delivery_variance
            FROM work_packages wp
            LEFT JOIN projects p ON wp.project_id = p.id
            LEFT JOIN users u ON wp.assigned_to_id = u.id
            LEFT JOIN statuses s ON s.id = wp.status_id
            WHERE {where_clause}
            GROUP BY p.name, u.firstname, u.lastname, u.id
            HAVING COUNT(wp.id) > 0
            ORDER BY p.name, avg_progress DESC
        """, *params)
        
        return dictify_rows(result)

# ============================================================================
# 4. FINANCIAL & BUDGET TOOLS (STUBS - ADAPT TO YOUR NEEDS)
# ============================================================================

@mcp.tool()
async def get_project_budget_summary(project_name: Optional[str] = None):
    """Get budget summary for projects (adapt based on your budget tracking)"""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        conditions = ["p.active = true"]
        params = []
        
        if project_name:
            conditions.append("(p.name ILIKE $1 OR p.identifier ILIKE $1)")
            params.append(f'%{project_name}%')
        
        where_clause = " AND ".join(conditions)
        
        result = await conn.fetch(f"""
            SELECT 
                p.name as project_name,
                p.identifier,
                COUNT(wp.id) as work_packages,
                SUM(wp.estimated_hours) as estimated_hours,
                SUM(wp.remaining_hours) as remaining_hours,
                AVG(wp.done_ratio) as completion_rate
            FROM projects p
            LEFT JOIN work_packages wp ON p.id = wp.project_id
            WHERE {where_clause}
            GROUP BY p.id, p.name, p.identifier
            ORDER BY p.name
        """, *params)
        
        return dictify_rows(result)

# ============================================================================
# 5. TIME TRACKING & PRODUCTIVITY TOOLS
# ============================================================================
        
@mcp.tool()
async def get_time_tracking_summary(
    project_name: Optional[str] = None,
    username: Optional[str] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None
):
    """Get comprehensive time tracking summary with filters"""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        conditions = ["te.spent_on IS NOT NULL"]
        params = []
        param_count = 0
        
        if project_name:
            param_count += 1
            conditions.append(f"p.name ILIKE ${param_count}")
            params.append(f'%{project_name}%')
        
        if username:
            param_count += 1
            conditions.append(f"(u.login ILIKE ${param_count} OR u.firstname || ' ' || u.lastname ILIKE ${param_count})")
            params.append(f'%{username}%')
        
        if start_date:
            param_count += 1
            conditions.append(f"te.spent_on >= ${param_count}")
            params.append(start_date)
        
        if end_date:
            param_count += 1
            conditions.append(f"te.spent_on <= ${param_count}")
            params.append(end_date)
        
        where_clause = " AND ".join(conditions)
        
        result = await conn.fetch(f"""
            SELECT 
                p.name as project_name,
                u.firstname || ' ' || u.lastname as user_name,
                wp.subject as work_package,
                a.name as activity,
                te.spent_on as date,
                te.hours,
                te.comments,
                te.created_on,
                SUM(te.hours) OVER (PARTITION BY p.id) as project_total_hours,
                SUM(te.hours) OVER (PARTITION BY u.id) as user_total_hours
            FROM time_entries te
            LEFT JOIN work_packages wp ON te.work_package_id = wp.id
            LEFT JOIN projects p ON te.project_id = p.id
            LEFT JOIN users u ON te.user_id = u.id
            LEFT JOIN time_entry_activities a ON te.activity_id = a.id
            WHERE {where_clause}
            ORDER BY te.spent_on DESC, te.created_on DESC
        """, *params)
        
        return dictify_rows(result)

# ============================================================================
# 6. REPORTING & ANALYTICS TOOLS
# ============================================================================

@mcp.tool()
async def get_activity_feed(days_back: int = 7, project_name: Optional[str] = None, limit: int = 50):
    """Get recent activity feed across projects"""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        start_date = datetime.now() - timedelta(days=days_back)

        conditions = [f"wp.updated_at >= $1"]
        params = [start_date]
        
        if project_name:
            conditions.append("(p.name ILIKE $2 OR p.identifier ILIKE $2)")
            params.append(f'%{project_name}%')
        
        params.append(limit)
        where_clause = " AND ".join(conditions)
        limit_clause = f"LIMIT ${len(params)}"
        
        result = await conn.fetch(f"""
            SELECT 
                wp.id as work_package_id,
                wp.subject,
                p.name as project_name,
                p.identifier,
                t.name as type,
                s.name as status,
                wp.done_ratio,
                u.firstname || ' ' || u.lastname as assignee,
                author.firstname || ' ' || author.lastname as author,
                wp.updated_at,
                wp.created_at,
                CASE
                    WHEN wp.updated_at = wp.created_at THEN 'Created'
                    WHEN wp.done_ratio = 100 THEN 'Completed'
                    ELSE 'Updated'
                END as activity_type,
                wp.updated_at - wp.created_at as time_since_creation
            FROM work_packages wp
            LEFT JOIN projects p ON wp.project_id = p.id
            LEFT JOIN types t ON wp.type_id = t.id
            LEFT JOIN statuses s ON wp.status_id = s.id
            LEFT JOIN users u ON wp.assigned_to_id = u.id
            LEFT JOIN users author ON wp.author_id = author.id
            WHERE {where_clause}
            ORDER BY wp.updated_at DESC
            {limit_clause}
        """, *params)
        
        return dictify_rows(result)

@mcp.tool()
async def get_overdue_tasks_analysis(project_name: Optional[str] = None, days_overdue: int = 0):
    """Analyze overdue tasks with detailed breakdown"""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        conditions = [f"wp.due_date < CURRENT_DATE - INTERVAL '{days_overdue} days'", "s.is_closed = false"]
        params = []
        
        if project_name:
            conditions.append("(p.name ILIKE $1 OR p.identifier ILIKE $1)")
            params.append(f'%{project_name}%')
        
        where_clause = " AND ".join(conditions)
        
        result = await conn.fetch(f"""
            SELECT 
                wp.id,
                wp.subject,
                p.name as project_name,
                t.name as type_name,
                s.name as status_name,
                e.name as priority_name,
                u.firstname || ' ' || u.lastname as assigned_to,
                wp.due_date,
                CURRENT_DATE - wp.due_date as days_overdue,
                wp.done_ratio,
                wp.estimated_hours,
                wp.remaining_hours,
                CASE 
                    WHEN wp.due_date < CURRENT_DATE - INTERVAL '30 days' THEN 'Critical'
                    WHEN wp.due_date < CURRENT_DATE - INTERVAL '7 days' THEN 'High'
                    WHEN wp.due_date < CURRENT_DATE THEN 'Medium'
                    ELSE 'Low'
                END as severity
            FROM work_packages wp
            LEFT JOIN projects p ON wp.project_id = p.id
            LEFT JOIN types t ON wp.type_id = t.id
            LEFT JOIN statuses s ON wp.status_id = s.id
            LEFT JOIN enumerations e ON wp.priority_id = e.id
            LEFT JOIN users u ON wp.assigned_to_id = u.id
            WHERE {where_clause}
            ORDER BY days_overdue DESC, wp.priority_id DESC
        """, *params)
        
        return dictify_rows(result)

# ============================================================================
# 7. CUSTOM QUERY TOOL (SAFE VERSION)
# ============================================================================

@mcp.tool()
async def execute_custom_query(sql_query: str):
    """Execute custom SQL query against OpenProject database (read-only)"""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        # Normalize the query for safety checks
        query_upper = sql_query.strip().upper()

        # Check if it starts with SELECT (allowing for comments)
        query_lines = [line.strip() for line in query_upper.split('\n') if line.strip()]
        first_meaningful_line = None
        for line in query_lines:
            if not line.startswith('--') and not line.startswith('/*'):
                first_meaningful_line = line
                break

        if not first_meaningful_line or not first_meaningful_line.startswith('SELECT'):
            return {"error": "Only SELECT queries are allowed"}

        # More sophisticated check for dangerous operations
        # Look for complete SQL statements, not just keywords in strings
        dangerous_patterns = [
            r'\bDROP\s+(?:TABLE|INDEX|VIEW|DATABASE)\b',
            r'\bDELETE\s+FROM\b',
            r'\bUPDATE\s+\w+\s+SET\b',
            r'\bINSERT\s+INTO\b',
            r'\bALTER\s+(?:TABLE|INDEX|VIEW)\b',
            r'\bTRUNCATE\s+TABLE\b',
            r'\bCREATE\s+(?:TABLE|INDEX|VIEW|DATABASE)\b',
            r'\bEXEC\b',
            r'\bEXECUTE\b'
        ]

        import re
        for pattern in dangerous_patterns:
            if re.search(pattern, query_upper, re.IGNORECASE):
                return {"error": "Query contains forbidden operations"}

        try:
            result = await conn.fetch(sql_query)
            return dictify_rows(result)
        except Exception as e:
            return {"error": f"Query execution failed: {str(e)}"}

# ============================================================================
# 8. ADDITIONAL UTILITY TOOLS
# ============================================================================

@mcp.tool()
async def search_work_packages_by_date(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    project_name: Optional[str] = None,
    status: Optional[str] = None,
    limit: int = 100
):
    """Search work packages by date range (updated_at)"""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        conditions = ["1=1"]
        params = []

        if start_date:
            conditions.append(f"wp.updated_at >= '{start_date}'")

        if end_date:
            conditions.append(f"wp.updated_at <= '{end_date}'")
        
        if project_name:
            conditions.append("(p.name ILIKE $3 OR p.identifier ILIKE $3)")
            params.append(f'%{project_name}%')
        
        if status:
            conditions.append("s.name ILIKE $4")
            params.append(f'%{status}%')
        
        params.append(limit)
        where_clause = " AND ".join(conditions)
        limit_clause = f"LIMIT ${len(params)}"
        
        result = await conn.fetch(f"""
            SELECT 
                wp.id,
                wp.subject,
                wp.description,
                wp.start_date,
                wp.due_date,
                wp.done_ratio,
                wp.estimated_hours,
                wp.updated_at,
                p.name as project_name,
                p.identifier as project_identifier,
                s.name as status_name,
                s.is_closed,
                t.name as type_name,
                u.firstname || ' ' || u.lastname as assigned_to_name,
                author.firstname || ' ' || author.lastname as author_name
            FROM work_packages wp
            LEFT JOIN projects p ON p.id = wp.project_id
            LEFT JOIN statuses s ON s.id = wp.status_id
            LEFT JOIN types t ON t.id = wp.type_id
            LEFT JOIN users u ON u.id = wp.assigned_to_id
            LEFT JOIN users author ON author.id = wp.author_id
            WHERE {where_clause}
            ORDER BY wp.updated_at DESC
            {limit_clause}
        """, *params)

        return dictify_rows(result)

@mcp.tool()
async def get_recently_updated_work_packages(days: int = 5, limit: int = 50):
    """Get work packages updated in the last N days"""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        start_date = datetime.now() - timedelta(days=days)

        result = await conn.fetch("""
            SELECT
                wp.id,
                wp.subject,
                wp.description,
                wp.start_date,
                wp.due_date,
                wp.done_ratio,
                wp.estimated_hours,
                wp.updated_at,
                wp.created_at,
                p.name as project_name,
                p.identifier as project_identifier,
                s.name as status_name,
                s.is_closed,
                t.name as type_name,
                u.firstname || ' ' || u.lastname as assigned_to_name,
                author.firstname || ' ' || author.lastname as author_name,
                CASE
                    WHEN wp.updated_at = wp.created_at THEN 'Newly Created'
                    WHEN wp.done_ratio = 100 THEN 'Completed'
                    ELSE 'Updated'
                END as update_type,
                EXTRACT(EPOCH FROM (wp.updated_at - wp.created_at))/86400 as days_since_creation
            FROM work_packages wp
            LEFT JOIN projects p ON p.id = wp.project_id
            LEFT JOIN statuses s ON s.id = wp.status_id
            LEFT JOIN types t ON t.id = wp.type_id
            LEFT JOIN users u ON u.id = wp.assigned_to_id
            LEFT JOIN users author ON author.id = wp.author_id
            WHERE wp.updated_at >= $1
            ORDER BY wp.updated_at DESC
            LIMIT $2
        """, start_date, limit)

        return dictify_rows(result)

@mcp.tool()
async def get_work_package_update_summary(days: int = 7):
    """Get summary of work package updates over the last N days"""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        start_date = datetime.now() - timedelta(days=days)

        result = await conn.fetch("""
            SELECT
                DATE(wp.updated_at) as update_date,
                COUNT(*) as total_updates,
                COUNT(CASE WHEN wp.updated_at = wp.created_at THEN 1 END) as new_work_packages,
                COUNT(CASE WHEN wp.done_ratio = 100 THEN 1 END) as completed_work_packages,
                COUNT(DISTINCT p.id) as projects_affected,
                COUNT(DISTINCT wp.assigned_to_id) as users_involved
            FROM work_packages wp
            LEFT JOIN projects p ON p.id = wp.project_id
            WHERE wp.updated_at >= $1
            GROUP BY DATE(wp.updated_at)
            ORDER BY update_date DESC
        """, start_date)

        return dictify_rows(result)

# ============================================================================
# 9. ANALYTICAL & INSIGHT TOOLS (READ-ONLY)
# ============================================================================

@mcp.tool()
async def analyze_data_quality(project_name: Optional[str] = None):
    """Analyze data quality issues and provide cleanup suggestions"""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        conditions = ["p.active = true"]
        params = []

        if project_name:
            conditions.append("(p.name ILIKE $1 OR p.identifier ILIKE $1)")
            params.append(f'%{project_name}%')

        where_clause = " AND ".join(conditions)

        result = await conn.fetch(f"""
            SELECT
                'Missing Descriptions' as issue_type,
                COUNT(*) as count,
                STRING_AGG(DISTINCT p.name, ', ') as affected_projects,
                'Add descriptions to improve tracking and understanding' as suggestion
            FROM work_packages wp
            JOIN projects p ON wp.project_id = p.id
            WHERE {where_clause} AND (wp.description IS NULL OR wp.description = '')

            UNION ALL

            SELECT
                'Tasks Without Assignees' as issue_type,
                COUNT(*) as count,
                STRING_AGG(DISTINCT p.name, ', ') as affected_projects,
                'Assign team members to ensure accountability' as suggestion
            FROM work_packages wp
            JOIN projects p ON wp.project_id = p.id
            WHERE {where_clause} AND wp.assigned_to_id IS NULL

            UNION ALL

            SELECT
                'Tasks Without Due Dates' as issue_type,
                COUNT(*) as count,
                STRING_AGG(DISTINCT p.name, ', ') as affected_projects,
                'Add due dates for better project planning' as suggestion
            FROM work_packages wp
            JOIN projects p ON wp.project_id = p.id
            WHERE {where_clause} AND wp.due_date IS NULL

            UNION ALL

            SELECT
                'Tasks Without Start Dates' as issue_type,
                COUNT(*) as count,
                STRING_AGG(DISTINCT p.name, ', ') as affected_projects,
                'Add start dates for timeline planning' as suggestion
            FROM work_packages wp
            JOIN projects p ON wp.project_id = p.id
            WHERE {where_clause} AND wp.start_date IS NULL

            ORDER BY count DESC
        """, *params)
        
        return dictify_rows(result)

@mcp.tool()
async def validate_project_dates(project_name: Optional[str] = None):
    """Check for date inconsistencies and provide correction suggestions"""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        conditions = ["p.active = true"]
        params = []

        if project_name:
            conditions.append("(p.name ILIKE $1 OR p.identifier ILIKE $1)")
            params.append(f'%{project_name}%')

        where_clause = " AND ".join(conditions)

        result = await conn.fetch(f"""
            SELECT
                wp.id,
                wp.subject,
                p.name as project_name,
                wp.start_date,
                wp.due_date,
                CASE
                    WHEN wp.start_date > wp.due_date THEN 'Start date after due date'
                    WHEN wp.due_date < CURRENT_DATE AND s.is_closed = false THEN 'Overdue task'
                    WHEN wp.start_date IS NULL AND wp.due_date IS NOT NULL THEN 'Missing start date'
                    WHEN wp.due_date IS NULL AND wp.start_date IS NOT NULL THEN 'Missing due date'
                    WHEN EXTRACT(days FROM (wp.due_date - wp.start_date)) > 365 THEN 'Unusually long duration'
                    ELSE 'Date inconsistency'
                END as issue_description,
                CASE
                    WHEN wp.start_date > wp.due_date THEN 'Consider correcting the dates or marking as milestone if no duration expected'
                    WHEN wp.due_date < CURRENT_DATE AND s.is_closed = false THEN 'Task is overdue - consider updating status or extending due date'
                    WHEN wp.start_date IS NULL THEN 'Add start date based on project timeline'
                    WHEN wp.due_date IS NULL THEN 'Add due date to enable proper planning'
                    WHEN wp.due_date - wp.start_date > INTERVAL '365 days' THEN 'Consider breaking into smaller tasks or verify dates'
                    ELSE 'Review dates for accuracy'
                END as suggestion
            FROM work_packages wp
            JOIN projects p ON wp.project_id = p.id
            LEFT JOIN statuses s ON wp.status_id = s.id
            WHERE {where_clause} AND (
                wp.start_date > wp.due_date OR
                (wp.due_date < CURRENT_DATE AND s.is_closed = false) OR
                (wp.start_date IS NULL AND wp.due_date IS NOT NULL) OR
                (wp.due_date IS NULL AND wp.start_date IS NOT NULL) OR
                (wp.due_date - wp.start_date) > 365
            )
            ORDER BY
                CASE
                    WHEN wp.start_date > wp.due_date THEN 1
                    WHEN wp.due_date < CURRENT_DATE AND s.is_closed = false THEN 2
                    ELSE 3
                END,
                wp.due_date ASC
        """, *params)

        return dictify_rows(result)

@mcp.tool()
async def find_missing_assignments(project_name: Optional[str] = None):
    """Identify work packages without assignees"""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        conditions = ["p.active = true", "wp.assigned_to_id IS NULL", "s.is_closed = false"]
        params = []

        if project_name:
            conditions.append("(p.name ILIKE $1 OR p.identifier ILIKE $1)")
            params.append(f'%{project_name}%')

        where_clause = " AND ".join(conditions)

        result = await conn.fetch(f"""
            SELECT
                p.name as project_name,
                p.identifier,
                COUNT(*) as unassigned_tasks,
                STRING_AGG(wp.subject, ' | ' ORDER BY wp.created_at DESC) as task_subjects,
                MIN(wp.due_date) as earliest_due_date,
                MAX(wp.priority_id) as highest_priority,
                CASE
                    WHEN COUNT(*) > 10 THEN 'High priority - many tasks need assignment'
                    WHEN COUNT(*) > 5 THEN 'Medium priority - several tasks unassigned'
                    ELSE 'Low priority - few tasks need assignment'
                END as priority_level,
                'Review and assign team members based on expertise and current workload' as suggestion
            FROM work_packages wp
            JOIN projects p ON wp.project_id = p.id
            LEFT JOIN statuses s ON wp.status_id = s.id
            WHERE {where_clause}
            GROUP BY p.id, p.name, p.identifier
            HAVING COUNT(*) > 0
            ORDER BY unassigned_tasks DESC, earliest_due_date ASC
        """, *params)

        return dictify_rows(result)

@mcp.tool()
async def get_project_improvement_suggestions(project_name: Optional[str] = None):
    """Provide actionable suggestions to improve project health"""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        conditions = ["p.active = true"]
        params = []

        if project_name:
            conditions.append("(p.name ILIKE $1 OR p.identifier ILIKE $1)")
            params.append(f'%{project_name}%')

        where_clause = " AND ".join(conditions)

        result = await conn.fetch(f"""
            WITH project_metrics AS (
                SELECT
                    p.id,
                    p.name,
                    p.identifier,
                    COUNT(wp.id) as total_tasks,
                    COUNT(CASE WHEN s.is_closed = true THEN 1 END) as completed_tasks,
                    COUNT(CASE WHEN wp.due_date < CURRENT_DATE AND s.is_closed = false THEN 1 END) as overdue_tasks,
                    COUNT(CASE WHEN wp.assigned_to_id IS NULL THEN 1 END) as unassigned_tasks,
                    COUNT(CASE WHEN wp.description IS NULL OR wp.description = '' THEN 1 END) as missing_descriptions,
                    AVG(wp.done_ratio) as avg_completion,
                    MIN(wp.start_date) as earliest_start,
                    MAX(wp.due_date) as latest_due
                FROM projects p
                LEFT JOIN work_packages wp ON wp.project_id = p.id
                LEFT JOIN statuses s ON s.id = wp.status_id
                WHERE {where_clause}
                GROUP BY p.id, p.name, p.identifier
            )
            SELECT
                name as project_name,
                identifier,
                CASE
                    WHEN overdue_tasks > 5 THEN 'Address overdue tasks immediately'
                    WHEN unassigned_tasks > total_tasks * 0.3 THEN 'Assign team members to unassigned tasks'
                    WHEN missing_descriptions > total_tasks * 0.2 THEN 'Add descriptions to tasks for better understanding'
                    WHEN avg_completion < 30 AND latest_due < CURRENT_DATE + INTERVAL '30 days' THEN 'Project may need additional resources or timeline extension'
                    WHEN total_tasks > 50 AND avg_completion > 80 THEN 'Consider project completion and handover planning'
                    WHEN unassigned_tasks = 0 AND overdue_tasks = 0 THEN 'Project is well-managed and on track'
                    ELSE 'Review project for potential improvements'
                END as suggestion,
                CASE
                    WHEN overdue_tasks > 5 THEN 'High'
                    WHEN unassigned_tasks > total_tasks * 0.3 THEN 'High'
                    WHEN missing_descriptions > total_tasks * 0.2 THEN 'Medium'
                    WHEN avg_completion < 30 AND latest_due < CURRENT_DATE + INTERVAL '30 days' THEN 'High'
                    ELSE 'Low'
                END as priority,
                total_tasks,
                completed_tasks,
                overdue_tasks,
                unassigned_tasks,
                ROUND(avg_completion, 1) as completion_percentage
            FROM project_metrics
            ORDER BY
                CASE priority
                    WHEN 'High' THEN 1
                    WHEN 'Medium' THEN 2
                    ELSE 3
                END,
                overdue_tasks DESC
        """, *params)

        return dictify_rows(result)

@mcp.tool()
async def analyze_workload_balance():
    """Analyze workload distribution across team members"""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        result = await conn.fetch("""
            WITH user_workload AS (
                SELECT
                    u.id,
                    u.firstname || ' ' || u.lastname as user_name,
                    COUNT(wp.id) as active_tasks,
                    COUNT(CASE WHEN wp.due_date < CURRENT_DATE AND s.is_closed = false THEN 1 END) as overdue_tasks,
                    COUNT(CASE WHEN wp.due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 7 THEN 1 END) as due_this_week,
                    AVG(wp.done_ratio) as avg_completion,
                    COUNT(DISTINCT p.id) as projects_involved
                FROM users u
                LEFT JOIN work_packages wp ON wp.assigned_to_id = u.id
                LEFT JOIN statuses s ON s.id = wp.status_id
                LEFT JOIN projects p ON p.id = wp.project_id
                WHERE u.status = 1  -- Active users only
                GROUP BY u.id, u.firstname, u.lastname
                HAVING COUNT(wp.id) > 0
            ),
            workload_stats AS (
                SELECT
                    AVG(active_tasks) as avg_tasks,
                    STDDEV(active_tasks) as stddev_tasks,
                    AVG(overdue_tasks) as avg_overdue
                FROM user_workload
            )
            SELECT
                uw.user_name,
                uw.active_tasks,
                uw.overdue_tasks,
                uw.due_this_week,
                ROUND(uw.avg_completion, 1) as completion_rate,
                uw.projects_involved,
                CASE
                    WHEN uw.active_tasks > (ws.avg_tasks + ws.stddev_tasks * 1.5) THEN 'Overloaded'
                    WHEN uw.active_tasks < (ws.avg_tasks - ws.stddev_tasks) THEN 'Underutilized'
                    ELSE 'Balanced'
                END as workload_status,
                CASE
                    WHEN uw.active_tasks > (ws.avg_tasks + ws.stddev_tasks * 1.5) THEN 'Consider redistributing tasks to balance workload'
                    WHEN uw.overdue_tasks > 3 THEN 'Focus on completing overdue tasks'
                    WHEN uw.due_this_week > 5 THEN 'Heavy week ahead - may need support'
                    WHEN uw.active_tasks < (ws.avg_tasks - ws.stddev_tasks) THEN 'Available for additional assignments'
                    ELSE 'Workload appears well-balanced'
                END as suggestion
            FROM user_workload uw
            CROSS JOIN workload_stats ws
            ORDER BY uw.active_tasks DESC
        """)

        return dictify_rows(result)

# ============================================================================
# 10. UTILITY TOOLS FOR NS POWER SPECIFIC NEEDS
# ============================================================================

@mcp.tool()
async def get_t_d_project_summary():
    """Get summary of T&D projects for NS Power executives"""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        result = await conn.fetch("""
            SELECT 
                p.name as project_name,
                p.identifier,
                p.status_code,
                COUNT(wp.id) as total_tasks,
                COUNT(CASE WHEN s.is_closed = true THEN 1 END) as completed_tasks,
                COUNT(CASE WHEN wp.due_date < CURRENT_DATE AND s.is_closed = false THEN 1 END) as overdue_tasks,
                AVG(wp.done_ratio) as completion_rate,
                COUNT(DISTINCT wp.assigned_to_id) as team_members,
                MIN(wp.start_date) as start_date,
                MAX(wp.due_date) as target_completion,
                CASE 
                    WHEN AVG(wp.done_ratio) >= 90 THEN 'Near Completion'
                    WHEN COUNT(CASE WHEN wp.due_date < CURRENT_DATE AND s.is_closed = false THEN 1 END) > 5 THEN 'At Risk'
                    WHEN AVG(wp.done_ratio) < 30 THEN 'Early Stage'
                    ELSE 'On Track'
                END as executive_status
            FROM projects p
            LEFT JOIN work_packages wp ON p.id = wp.project_id
            LEFT JOIN statuses s ON s.id = wp.status_id
            WHERE p.active = true AND p.name ILIKE '%T&D%' OR p.name ILIKE '%Transmission%' OR p.name ILIKE '%Distribution%'
            GROUP BY p.id, p.name, p.identifier, p.status_code
            ORDER BY 
                CASE executive_status 
                    WHEN 'At Risk' THEN 1
                    WHEN 'On Track' THEN 2
                    WHEN 'Near Completion' THEN 3
                    ELSE 4 
                END,
                completion_rate DESC
        """)
        
        return dictify_rows(result)

@mcp.tool()
async def get_project_risk_assessment(project_name: Optional[str] = None):
    """Assess project risks based on various metrics"""
    pool = await get_db_pool()
    async with pool.acquire() as conn:
        conditions = ["p.active = true"]
        params = []
        
        if project_name:
            conditions.append("(p.name ILIKE $1 OR p.identifier ILIKE $1)")
            params.append(f'%{project_name}%')
        
        where_clause = " AND ".join(conditions)
        
        result = await conn.fetch(f"""
            SELECT 
                p.name as project_name,
                p.identifier,
                
                -- Schedule Risks
                COUNT(CASE WHEN wp.due_date < CURRENT_DATE AND s.is_closed = false THEN 1 END) as overdue_tasks,
                COUNT(CASE WHEN wp.due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days' 
                      AND s.is_closed = false THEN 1 END) as due_this_week,
                COUNT(CASE WHEN wp.start_date IS NULL THEN 1 END) as unstarted_tasks,
                
                -- Resource Risks
                COUNT(CASE WHEN wp.assigned_to_id IS NULL THEN 1 END) as unassigned_tasks,
                COUNT(DISTINCT wp.assigned_to_id) as assigned_users,
                
                -- Quality Risks
                COUNT(CASE WHEN s.name = 'Blocked' THEN 1 END) as blocked_tasks,
                COUNT(CASE WHEN s.name = 'RE-WORK' THEN 1 END) as rework_tasks,
                
                -- Overall Risk Score
                CASE 
                    WHEN COUNT(CASE WHEN wp.due_date < CURRENT_DATE AND s.is_closed = false THEN 1 END) > 10 THEN 'Critical'
                    WHEN COUNT(CASE WHEN wp.due_date < CURRENT_DATE AND s.is_closed = false THEN 1 END) > 5 
                         OR COUNT(CASE WHEN wp.assigned_to_id IS NULL THEN 1 END) > 10 THEN 'High'
                    WHEN COUNT(CASE WHEN wp.due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days' THEN 1 END) > 5
                         OR AVG(wp.done_ratio) < 30 THEN 'Medium'
                    ELSE 'Low'
                END as risk_level,
                
                AVG(wp.done_ratio) as completion_rate,
                MAX(wp.updated_at) as last_update
                
            FROM projects p
            LEFT JOIN work_packages wp ON p.id = wp.project_id
            LEFT JOIN statuses s ON s.id = wp.status_id
            WHERE {where_clause}
            GROUP BY p.id, p.name, p.identifier
            ORDER BY 
                CASE risk_level 
                    WHEN 'Critical' THEN 1
                    WHEN 'High' THEN 2
                    WHEN 'Medium' THEN 3
                    ELSE 4 
                END
        """, *params)
        
        return dictify_rows(result)

# ============================================================================
# SERVER STARTUP
# ============================================================================

if __name__ == "__main__":
    mcp.run(transport="sse", port=8000, host="0.0.0.0")