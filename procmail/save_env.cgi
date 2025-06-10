#!/usr/local/bin/perl
# save_env.cgi
# Create, update or delete an environment setting

require './procmail-lib.pl';
&ReadParse();
&lock_file($procmailrc);
@conf = &get_procmailrc();
$env = $conf[$in{'idx'}] if (!$in{'new'});

if ($in{'delete'}) {
	# Just delete the variable
	&delete_recipe($env);
	}
else {
	# Validate inputs
	&error_setup($text{'env_err'});
	$in{'name'} =~ /^[^\s=]+$/ || &error($text{'env_ename'});
	$env->{'name'} = $in{'name'};
	$in{'value'} =~ s/\r//g;
	$env->{'value'} = $in{'value'};

	# Save the receipe
	if ($in{'new'}) {
		&create_recipe($env);
		}
	else {
		&modify_recipe($env);
		}
	}
&unlock_file($procmailrc);
&webmin_log($in{'delete'} ? "delete" : $in{'new'} ? "create" : "modify",
	    "env", undef, $env);
&redirect("");

