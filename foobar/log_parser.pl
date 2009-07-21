# log_parser.pl
# Functions for parsing this module's logs

do 'foobar-lib.pl';

=head2 parse_webmin_log(user, script, action, type, object, &params)

Converts logged information from this module into human-readable form

=cut
sub parse_webmin_log
{
my ($user, $script, $action, $type, $object, $p) = @_;
return &text('log_'.$action, '<tt>'.html_escape($object).'</tt>');
}

