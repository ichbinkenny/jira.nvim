local io = require("io")
local M = {}
local curl = require("plenary.curl")
local HTTP_OK = 200

local temp_user_url = ""

local get_credentials = function()
    local user = os.getenv("JIRA_USERNAME")
    if not user then
        user = ""
    end
    local token = os.getenv("JIRA_API_TOKEN")
    if not token then
        token = ""
    end
    return user .. ":" .. token
end

local get_jira_url = function()
    local url = os.getenv("JIRA_URL")
    if not url then
        url = temp_user_url
    end
    return url
end

M.list_jira_projects = function(opts)
    print("Jira Projects")
end

M.select = function()
    print("SELECT!")
end

M.get_jira_projects = function(opts)
    local projects_table = {}
    local credential_string = get_credentials()
    local url = get_jira_url() .. "/rest/api/3/project/search"
    local project_response = curl.get(url, {
        auth = credential_string,
        headers = {
            accept = "application/json",
        },
        compressed = false
    })
    if project_response.status == HTTP_OK then
        local projects = vim.fn.json_decode(project_response.body).values
        local project,project_fields=next(projects, nil)
        while project do
            local project_name = projects[project].name
            local project_key = projects[project].key
            local project_id = projects[project].id
            print(project_name .. " (" .. project_key .. "): " .. project_id)
            table.insert(projects_table, {name = project_name, key = project_key, id = project_id})
            project, project_fields = next(projects, project)
        end
    end
    return projects_table
end

M.test_jira_connection = function(opts)
    local credential_string = get_credentials()
    local url = get_jira_url()
    local test = curl.get(url.."/rest/api/3/dashboard", {
        auth = credential_string,
        headers = {
            accept = "application/json",
        },
        compressed = false,
    })
    if test.status == HTTP_OK then
        print("Connection Successful!")
    else
        error("Connection Failed")
    end
end

M.get_project_issues = function(project_info)
    local credential_string = get_credentials()
    local url = get_jira_url() .. "/rest/api/3/search?jql=project=" .. project_info.args .. "&fields=names,summary"
    local resp = curl.get(url, {
        auth = credential_string,
        headers = {
            accept = "application/json",
        },
        compressed = false,
    })
    print("Response: " .. resp.body)
end

local find_agile_board_id = function(board_name)
    local available_boards = M.get_jira_boards()
    local board, vals = next(available_boards, nil)
    while board do
        if vals.name ==# board_name or vals.key == board_name then
            return vals.id
        end
        board, vals = next(available_boards, board)
    end
    return 0
end

M.get_current_sprint = function(board)
    local current_sprint_info = {}
    local board_id = tonumber(board.args)
    if not board_id then
        board_id = find_agile_board_id(board.args)
    end
    print(board_id)
    local credential_string = get_credentials()
    local url = get_jira_url() .. "/rest/agile/1.0/board/" .. board_id .. "/sprint?state=active"
    local resp = curl.get(url, {
        auth = credential_string,
        headers = {
            accept = "application/json",
        },
        compressed = false,
    })
    if resp.status == HTTP_OK then
        local sprint_resp = vim.fn.json_decode(resp.body).values
        local k, v = next(sprint_resp, nil)
        while k do
            table.insert(current_sprint_info, { id = v.id, name = v.name, origin_id = v.originBoardId, goal = v.goal, start_date = v.startDate, end_date = v.endDate, url = v.self})
            print("Sprint: " .. v.name .. ", Goal: " .. v.goal)
            k, v = next(sprint_resp, k)
        end
    else
        print("Failed to get sprint response. Erro: " .. resp.status)
    end
    return current_sprint_info
end

M.get_current_sprint_issues = function(board_id)

end


M.get_sprint_issues = function(board)
    local board_id = tonumber(board.args)
    if not board_id then
        -- lookup board id
        board_id = find_agile_board_id(board.args)
    end
    local url = get_jira_url() .. "/rest/agile/1.0/board/" .. board_id .. "/sprint"
    local credential_string = get_credentials()
    local resp = curl.get(url, {
        auth = credential_string,
        headers = {
            accept = "application/json",
        },
        compressed = false,
    })
    if resp.status == HTTP_OK then
        local sprint_info = vim.fn.json_decode(resp.body).values
        local key, entry = next(sprint_info, nil)
        while key do
            print(entry)
            key, entry = next(sprint_info, key)
        end
    end
end

M.set_jira_url = function(input)
    temp_user_url = input.args
    print("URL set to " .. temp_user_url)
end

M.get_jira_boards = function()
    local boards_info = {}
    local url = get_jira_url() .. "/rest/agile/1.0/board"
    local credential_string = get_credentials()
    local resp = curl.get(url, {
        auth = credential_string,
        headers = {
            accept = "application/json",
        },
        compressed = false,
    })
    if resp.status == HTTP_OK then
        local boards_resp = vim.fn.json_decode(resp.body).values
        local k,v = next(boards_resp, nil)
        while k do
            table.insert(boards_info, { name = v.name, id = v.id, key = v.location.projectKey})
            k,v = next(boards_resp, k)
        end
        return boards_info
    end
end

M.setup = function(opts)
    vim.api.nvim_create_user_command('JiraConnectionTest', M.test_jira_connection, opts)
    vim.api.nvim_create_user_command('JiraProjects', M.get_jira_projects, opts)
    vim.api.nvim_create_user_command("JiraBoards", M.get_jira_boards, opts)
    vim.api.nvim_create_user_command('JiraSetURL', M.set_jira_url, {nargs=1})
    vim.api.nvim_create_user_command("JiraProjectIssues", M.get_project_issues, {nargs=1})
    vim.api.nvim_create_user_command('JiraListSprints', M.get_current_sprint_issues, opts)
    vim.api.nvim_create_user_command('JiraSprintInfo', M.get_sprint_issues, {nargs=1})
    vim.api.nvim_create_user_command('CurrentSprint', M.get_current_sprint, {nargs=1})
end

return M
