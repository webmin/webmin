# webmin-driver.pl
# Functions for webmin print and smb drivers.
# These are all just calls to the standard driver functions.

$webmin_windows_driver = 1;
$webmin_print_driver = 1;

# is_windows_driver(path)
# Returns a driver structure if some path is a windows driver
sub is_windows_driver
{
return &is_webmin_windows_driver(@_);
}

# is_driver(path)
# Returns a structure containing the details of a driver
sub is_driver
{
return &is_webmin_driver(@_);
}

# create_windows_driver(&printer, &driver)
# Creates a new windows printer driver
sub create_windows_driver
{
return &create_webmin_windows_driver(@_);
}

# create_driver(&printer, &driver)
# Creates a new local printer driver and returns the path
sub create_driver
{
return &create_webmin_driver(@_);
}

# delete_driver(name)
sub delete_driver
{
&delete_webmin_driver(@_);
}

# driver_input(&printer, &driver)
sub driver_input
{
return &webmin_driver_input(@_);
}

# parse_driver()
# Parse driver selection from %in and return a driver structure
sub parse_driver
{
return &parse_webmin_driver(@_);
}

1;

