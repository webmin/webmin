# log_parser.pl
# Functions for parsing this module's logs

do 'updown-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
if ($action eq "upload") {
	local @uploads = split(/\0/, $p->{'uploads'});
	if ($long) {
		return &text('log_upload_l',
		 join(" ", map { "<tt>".&html_escape($_)."</tt>" } @uploads));
		}
	else {
		return &text('log_upload', scalar(@uploads));
		}
	}
elsif ($action eq "download") {
	local $pfx = $p->{'time'} ? "log_sdownload" : "log_download";
	local @downloads = split(/\0/, $p->{'urls'});
	if ($long) {
		return &text($pfx.'_l',
		 join(" ", map { "<tt>".&html_escape($_)."</tt>" } @downloads));
		}
	else {
		return &text($pfx, scalar(@downloads));
		}
	}
elsif ($action eq "cancel") {
	local @ids = split(/\0/, $p->{'ids'});
	return &text('log_cancel', scalar(@ids));
	}
}

