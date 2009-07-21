# log_parser.pl
# Functions for parsing this module's logs

do 'mailcap-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq 'mailcap') {
  return &text('log_'.$action.'_mailcap', "<tt>".&html_escape($object)."</tt>");
  }
elsif ($type eq 'mailcaps') {
  return &text('log_'.$action.'_mailcaps', $object);
  }
else {
  return undef;
  }
}

