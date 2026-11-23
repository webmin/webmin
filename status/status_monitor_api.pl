
# status_monitor_list()
# Returns a list of monitor types defined by this module, each of which must
# be a two-element array reference
sub status_monitor_list
{
}

# status_monitor_status(type, &monitor, [from-ui])
# Returns a status object for a monitor with the given type and info structure
sub status_monitor_status
{
}

# status_monitor_dialog(type, &monitor)
# Returns HTML for a dialog for options for a monitor of the given type
sub status_monitor_dialog
{
}

# status_monitor_parse(type, &monitor, &in)
# Updates the monitor object with values from the form
sub status_monitor_parse
{
}

# status_monitor_dashboard(&data)
# Returns permitted services with stable id, plain-text desc and up of 0 or 1
# Optional type matches a saved monitor; manage is a root-relative module URL
# data contains dashboard options. Requires status_dashboard=1 in module.info
sub status_monitor_dashboard
{
}

# status_monitor_actions(type, &monitor, up)
# Returns a list of actions as [kind, label, cgi, optional fields hashref]
# Each handler must check permissions and return to the calling page
sub status_monitor_actions
{
}

1;

