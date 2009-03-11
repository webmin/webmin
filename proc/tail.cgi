#!/usr/local/bin/perl

require './proc-lib.pl';
&ReadParse();
if ($in{'id'}) {
	$idfile = "$module_config_directory/$in{'id'}.tail";
	open(IDFILE, ">$idfile");
	print IDFILE $$,"\n";
	close(IDFILE);
	$SIG{'HUP'} = \&hup_handler;
	}
$| = 1;
print "Content-type: text/plain\n\n";
$trace = &open_process_trace($in{'pid'},
			     $in{'syscalls'} ? [ split(/\s+/, $in{'syscalls'}) ]
					     : undef);
while($action = &read_process_trace($trace)) {
	local $tm = strftime("%H:%M:%S", localtime($action->{'time'}));
	print join("\t", $tm, $action->{'call'},
			 join(", ", @{$action->{'args'}}),
			 $action->{'rv'}),"\n";
	}
&close_process_trace($trace);
unlink($idfile) if ($idfile);

sub hup_handler
{
&close_process_trace($trace);
unlink($idfile);
exit;
}

