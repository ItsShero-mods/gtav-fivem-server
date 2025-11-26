Config = {}

-- UI Configuration
Config.UI = {
    menuPosition = 'top-right',  -- Menu position: 'top-right', 'top-left', 'bottom-right', 'bottom-left'
    notifications = {
        start = {
            title = 'Starting to throw money',
            type = 'success'
        },
        success = {
            title = "Threw One Bill",
            type = 'success'
        },
        error = {
            title = 'Stopped Throwing',
            type = 'error'
        },
        cooldown = {
            title = "On Cooldown",
            type = 'error'
        }
    }
}