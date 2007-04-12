# log_parser.pl
# Functions for parsing this module's logs

do 'spam-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
return $text{'log_'.$action};
}

