# log_parser.pl
# Functions for parsing this module's logs

do 'krb5-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params, [long])
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
    
return undef;    
}
