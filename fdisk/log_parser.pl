# log_parser.pl
# Functions for parsing this module's logs

do 'fdisk-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p) = @_;
if ($type eq 'part') {
	return &text("log_${action}", &part_name2($object, $p->{'np'}));
	}
elsif ($action eq 'mkfs' || $action eq 'tunefs' || $action eq 'fsck') {
	return &text("log_${action}", "<tt>".uc($p->{'type'})."</tt>",
		     &part_name($object));
	}
elsif ($action eq 'hdparm') {
	return &text('log_hdparm', &device_name($object));
	}
else {
	return undef;
	}
}

sub part_name2
{
return $_[0] =~ /^\/dev\/(s|h)d([a-z])$/ ?
	&text('select_part', $1 eq 's' ? 'SCSI' : 'IDE', uc($2), $_[1]) :
       $_[0] =~ /rd\/c(\d+)d(\d+)$/ ?
	&text('select_mpart', "$1", "$2", $_[1]) :
       $_[0] =~ /ida\/c(\d+)d(\d+)$/ ?
	&text('select_cpart', "$1", "$2", $_[1]) :
	$_[0];
}

sub part_name
{
return $_[0] =~ /^\/dev\/(s|h)d([a-z])(\d+)$/ ?
	&text('select_part', $1 eq 's' ? 'SCSI' : 'IDE', uc($2), "$3") :
       $_[0] =~ /rd\/c(\d+)d(\d+)p(\d+)$/ ?
	&text('select_mpart', "$1", "$2", "$3") :
       $_[0] =~ /ida\/c(\d+)d(\d+)p(\d+)$/ ?
	&text('select_cpart', "$1", "$2", "$3") :
	$_[0];
}

sub device_name
{
return $_[0] =~ /^\/dev\/(s|h)d([a-z])$/ ?
	&text('select_device', $1 eq 's' ? 'SCSI' : 'IDE', uc($2)) :
       $_[0] =~ /rd\/c(\d+)d(\d+)$/ ?
	&text('select_mylex', "$1", "$2") :
       $_[0] =~ /ida\/c(\d+)d(\d+)$/ ?
	&text('select_cpq', "$1", "$2") :
	$_[0];
}
