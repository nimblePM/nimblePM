# OpenProject MCP Server for NS Power T&D Workplans

## 📋 Overview

This is an enhanced Model Context Protocol (MCP) server that provides intelligent, read-only access to NS Power's Transmission & Distribution (T&D) workplans stored in OpenProject. The server enables natural language queries about project status, team workloads, data quality, and project insights.

## 🎯 Current Capabilities

### **✅ Successfully Implemented Tools (25+ tools)**

#### **1. Project Overview & Status Tools**
- `get_project_overview()` - Comprehensive project summaries with metrics
- `get_project_hierarchy()` - Parent-child project relationships
- `get_project_health_report()` - Risk assessment and health scoring

#### **2. Work Package Management Tools**
- `search_work_packages()` - Advanced filtering by status, assignee, type, priority
- `get_work_package_timeline()` - Upcoming deadlines and milestones
- `get_work_package_dependencies()` - Task dependencies and blockers

#### **3. Resource & Workload Management Tools**
- `get_user_workload()` - Individual team member workload analysis
- `get_team_performance()` - Team productivity metrics
- `analyze_workload_balance()` - **NEW** - Team workload distribution analysis

#### **4. Time Tracking & Analytics Tools**
- `get_time_tracking_summary()` - Time spent analysis by project/user
- `get_recently_updated_work_packages()` - **NEW** - Work updated in last N days
- `get_work_package_update_summary()` - **NEW** - Daily activity summaries

#### **5. Reporting & Activity Tools**
- `get_activity_feed()` - Recent project activity with proper ID resolution
- `get_overdue_tasks_analysis()` - Overdue task identification
- `search_work_packages_by_date()` - **NEW** - Date range filtering

#### **6. Analytical & Insight Tools (NEW)**
- `analyze_data_quality()` - **NEW** - Data quality issue identification
- `validate_project_dates()` - **NEW** - Date inconsistency detection
- `find_missing_assignments()` - **NEW** - Unassigned task identification
- `get_project_improvement_suggestions()` - **NEW** - Actionable project improvements

#### **7. Financial & Budget Tools**
- `get_project_budget_summary()` - Budget utilization tracking

#### **8. Utility & Custom Query Tools**
- `execute_custom_query()` - Safe read-only SQL queries
- `get_t_d_project_summary()` - T&D-specific project summaries

## 🔧 Technical Implementation

### **Connection & Performance**
- **Async PostgreSQL**: High-performance asyncpg connections
- **Connection Pooling**: Efficient resource management (2-10 connections)
- **Error Handling**: Robust error handling with meaningful messages
- **Data Serialization**: Automatic JSON conversion for dates/decimals

### **Key Features**
- **ID Resolution**: All IDs automatically resolved to human-readable names
- **Read-Only Operations**: No database modifications, only analysis
- **Safe Query Execution**: Restricted SQL queries with pattern matching
- **Comprehensive Filtering**: Date ranges, project names, user names, etc.

## 📊 Data Quality Insights

### **Major Findings (as of latest analysis):**
- **3,428 tasks missing descriptions** across all projects
- **1,549 tasks without assignees** affecting accountability
- **1,090 tasks without start dates** impacting timeline planning
- **1,078 tasks without due dates** affecting project planning

### **Team Workload Analysis:**
- **5 team members currently overloaded** (200+ active tasks each)
- **70+ overdue tasks** requiring immediate attention
- **Statistical workload balancing** with automated recommendations

## 🎯 Recommended Pre-Filled Questions

### **8 Key Questions for Chatbot Interface:**
1. *"What is the current status of the 91H Transformer Replacement project?"*
2. *"Which team members are overloaded this month?"*
3. *"What work packages are due in the next 7 days?"*
4. *"Show me data quality issues across all active projects"*
5. *"What was updated in projects during the last 5 days?"*
6. *"What tasks are unassigned in the 91H project?"*
7. *"What is the budget summary for T&D projects?"*
8. *"Generate a workload balance analysis for the team"*

## 🚀 Deployment & Development Workflow

### **Development Environment:**
- **Local VM**: `192.168.3.77` (development/testing)
- **Production Server**: `192.168.3.99` (Unraid Docker container)

### **Deployment Process:**
```bash
# 1. Make changes on development VM
# 2. Copy to production server
scp openproject_mcp.py user@192.168.3.99:/mnt/nvme/appdata/mcp-openproject/

# 3. Restart Docker container
docker restart mcp-openproject
```

### **Alternative: Volume Mounting (Faster Development)**
```bash
docker run -d \
  --name mcp-openproject \
  --network host \
  -e DB_HOST=192.168.3.78 \
  -e DB_PORT=5432 \
  -e DB_NAME=openproject \
  -e DB_USER=openproject \
  -e DB_PASSWORD=openproject \
  -v /mnt/nvme/appdata/mcp-openproject/openproject_mcp.py:/app/openproject_mcp.py \
  --restart unless-stopped \
  mcp-openproject
```

### **Running OpenProject services (this fork)**

For starting the OpenProject stack that this MCP connects to, use the canonical commands in `AI_CHAT_INSTRUCTIONS.md` (docker compose with `--env-file env.production`). Keeping those commands in a single place ensures AI chats and humans use the same, up-to-date procedure.

## 📈 Future Enhancements

### **Potential Improvements:**
1. **API Integration**: Add confirmed database modification capabilities
2. **Advanced Analytics**: Predictive workload forecasting
3. **Automated Reports**: Scheduled summary emails
4. **Integration APIs**: SAP, GIS, weather data connections
5. **Mobile Optimization**: Mobile-friendly query responses

### **Known Issues:**
- `validate_project_dates()` - Has PostgreSQL date arithmetic issues (needs refinement)
- `get_project_improvement_suggestions()` - ORDER BY alias reference issue

## 🏗️ Architecture

### **Database Schema Understanding:**
- **Projects**: Hierarchical structure with status codes
- **Work Packages**: Tasks with assignees, dates, priorities
- **Users**: Team members with roles and status
- **Statuses**: Task completion states (Not Started, In Progress, Complete)
- **Types**: Task categories (Task, Milestone, Phase, etc.)
- **Relations**: Task dependencies and blocking relationships

### **Security Model:**
- **Read-Only**: All operations are SELECT-only
- **Safe Queries**: Pattern matching prevents dangerous operations
- **Parameter Binding**: SQL injection protection via parameterized queries

## 📞 Usage Examples

### **For Executives:**
```python
# Get high-level project status
get_project_overview()

# Check data quality across portfolio
analyze_data_quality()
```

### **For Project Managers:**
```python
# Find unassigned work
find_missing_assignments("91H")

# Check team workload
analyze_workload_balance()
```

### **For Engineers:**
```python
# See upcoming deadlines
get_work_package_timeline(days_ahead=7)

# Check recent updates
get_recently_updated_work_packages(days=3)
```

## 🎯 Impact & Value

### **Current Value Delivered:**
- **Data Quality Insights**: Identified 6,000+ data quality issues
- **Workload Optimization**: Automated team capacity analysis
- **Project Visibility**: Real-time status across 100+ projects
- **Time Savings**: Instant answers to common questions

### **Stakeholder Benefits:**
- **Executives**: Portfolio-level insights and risk identification
- **Managers**: Resource allocation and project health monitoring
- **Engineers**: Task visibility and deadline awareness
- **Teams**: Improved collaboration and workload balance

## 🔄 Recent Updates (August 2025)

- ✅ **Fixed**: Activity feed column reference issues
- ✅ **Enhanced**: Custom query safety filtering
- ✅ **Added**: 5 new analytical tools for data quality and workload analysis
- ✅ **Improved**: Date handling and parameter validation
- ✅ **Optimized**: Connection pooling for better performance

---

**This MCP server transforms your OpenProject database into an intelligent project management assistant, providing actionable insights without compromising data integrity.** 🚀

*Last Updated: August 28, 2025*
