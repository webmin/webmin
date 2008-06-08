#!/usr/local/bin/perl
# renice_proc.cgi
# Change the nice level of a process, and possibly the IO scheduling

require './proc-lib.pl';
&ReadParse();
&switch_acl_uid();
&error_setup(&text('renice_err', $in{pid}));
%pinfo = &process_info($in{pid});

# Set nice level
&can_edit_process($pinfo{'user'}) || &error($text{'renice_ecannot'});
if ($error = &renice_proc($in{'pid'}, $in{nice})) {
	&error($error);
	}

# Set IO scheduling
if (defined($in{'sclass'})) {
	$error = &os_set_scheduling_class(
		$in{'pid'}, $in{'sclass'}, $in{'sprio'});
	}

&webmin_log("renice", undef, undef, \%in);
&redirect("edit_proc.cgi?$in{pid}");

