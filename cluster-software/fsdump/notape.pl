#!/usr/local/bin/perl
# notape.pl
# Called when a foreground backup requests a new tape. Always fails, because
# tape changing is not supported in this case

$no_acl_check++;
delete($ENV{'SCRIPT_NAME'});	# force use of $0 to determine module
delete($ENV{'FOREIGN_MODULE_NAME'});
require './fsdump-lib.pl';
$dump = &get_dump($ARGV[0]);
$dump->{'id'} || die "Dump $ARGV[0] does not exist!";

&open_tempfile(NOTAPE, ">$module_config_directory/$dump->{'id'}.notape");
&close_tempfile(NOTAPE);
exit(2);

