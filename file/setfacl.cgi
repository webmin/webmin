#!/usr/local/bin/perl
# setfacl.cgi
# Sets the ACLs for some file

require './file-lib.pl';
$disallowed_buttons{'acl'} && &error($text{'ebutton'});
&ReadParse();
&webmin_log("acl", undef, $in{'file'}, \%in);
&switch_acl_uid_and_chroot();
print "Content-type: text/plain\n\n";
if ($access{'ro'} || !&can_access($in{'file'})) {
	print $text{'facl_eaccess'},"\n";
	}
else {
	pipe(ACLINr, ACLINw);
	pipe(ACLOUTr, ACLOUTw);
	$pid = fork();
	if (!$pid) {
		untie(*STDIN);
		untie(*STDOUT);
		untie(*STDERR);
		open(STDIN, "<&ACLINr");
		open(STDOUT, ">&ACLOUTw");
		open(STDERR, ">&ACLOUTw");
		close(ACLINw);
		close(ACLOUTr);
		exec("$config{'setfacl'} '$in{'file'}'");
		print "Exec failed : $!\n";
		exit(1);
		}
	close(ACLINr);
	close(ACLOUTw);
	print ACLINw $in{'acl'},"\n";
	close(ACLINw);
	waitpid($pid, 0);
	$rv = <ACLOUTr>;
	close(ACLOUTr);
	if ($rv) {
		print $rv;
		}
	else {
		print "\n";
		}
	}

