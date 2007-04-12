#!/usr/local/bin/perl
# renice_proc.cgi
# Change the nice level of a process

require './proc-lib.pl';
&ReadParse();
&switch_acl_uid();
&error_setup(&text('renice_err', $in{pid}));
%pinfo = &process_info($in{pid});
&can_edit_process($pinfo{'user'}) || &error($text{'renice_ecannot'});
if ($error = &renice_proc($in{pid}, $in{nice})) {
	&error($error);
	}
&redirect("edit_proc.cgi?$in{pid}");

