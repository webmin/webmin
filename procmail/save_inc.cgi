#!/usr/local/bin/perl
# save_inc.cgi
# Create, update or delete an include file

require './procmail-lib.pl';
&ReadParse();
&lock_file($procmailrc);
@conf = &get_procmailrc();
$inc = $conf[$in{'idx'}] if (!$in{'new'});

if ($in{'delete'}) {
	# Just delete the variable
	&delete_recipe($inc);
	}
else {
	# Validate inputs
	&error_setup($text{'env_err'});
	$in{'inc'} =~ /\S/ || &error($text{'inc_einc'});
	$inc->{'include'} = $in{'inc'};

	# Save the receipe
	if ($in{'new'}) {
		&create_recipe($inc);
		}
	else {
		&modify_recipe($inc);
		}
	}
&unlock_file($procmailrc);
&webmin_log($in{'delete'} ? "delete" : $in{'new'} ? "create" : "modify",
	    "inc", undef, $inc);
&redirect("");

