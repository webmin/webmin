# uninstall.pl
# Called when webmin is uninstalled to delete and at jobs

require 'updown-lib.pl';

sub module_uninstall
{
if (&foreign_check("at")) {
	&foreign_require("at", "at-lib.pl");
	@ats = &at::list_atjobs();
	foreach $a (@ats) {
		if ($a->{'realcmd'} =~ /\Q$atjob_cmd\E\s+(\d+)/) {
			&at::delete_atjob($a->{'id'});
			}
		}
	}
}

