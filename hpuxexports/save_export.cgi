#!/usr/local/bin/perl
# save_export.cgi
# Save, create or delete an export

require './exports-lib.pl';
&ReadParse();
&lock_file($config{'exports_file'});
@exps = &list_exports();

if ($in{'delete'}) {
	# Deleting some export
	$exp = $exps[$in{'idx'}];
	&delete_export($exp);
	}
else {
	if (!$in{'new'}) {
		# Get old export
		$oldexp = $exps[$in{'idx'}];
		%opts = %{$oldexp->{'options'}};
		}

	# check dir and active
	&error_setup($text{'save_err'});
	-d $in{'dir'} || &error(&text('save_edir', $in{'dir'}));
	$exp{'dir'} = $in{'dir'};
	$exp{'active'} = $in{'active'};

	# check inputs
	&check_inputs();

	# validate and parse options
	&set_options();

	$exp{'options'} = \%opts;
	if ($in{'new'}) {
		&create_export(\%exp);
		}
	else {
		&modify_export(\%exp, $oldexp);
		}
	}
&unlock_file($config{'exports_file'});
if ($in{'delete'}) {
	&webmin_log("delete", "export", $exp->{'dir'}, $exp);
	}
elsif ($in{'new'}) {
	&webmin_log("create", "export", $exp{'dir'}, \%exp);
	}
else {
	&webmin_log("modify", "export", $exp{'dir'}, \%exp);
	}
&redirect("");

