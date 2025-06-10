# log_parser.pl
# Functions for parsing this module's logs

do 'cluster-copy-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
if ($action eq 'deletes') {
	# Deleting multiple jobs
	return &text('log_deletes', $object);
	}
else {
	# Some action on a job
	local @files = split(/\t+/, $p->{'files'});
	local $files = @files > 1 ? scalar(@files)." files"
				  : join(", ", @files);
	local @servers = split(/\s+/, $p->{'servers'});
	local $servers = scalar(@servers);
	return &text('log_'.$action, $files, $servers);
	}
}

