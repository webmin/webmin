#!/usr/local/bin/perl
# save_other.cgi

require './lilo-lib.pl';
&ReadParse();

&lock_file($config{'lilo_conf'});
$conf = &get_lilo_conf();
if ($in{'delete'}) {
	# deleting an existing partition
	$other = $conf->[$in{'idx'}];
	&save_directive($conf, $other);
	&flush_file_lines();
	&unlock_file($config{'lilo_conf'});
	&webmin_log("delete", "other",
		    &find_value("label", $other->{'members'}), \%in);
	&redirect("");
	exit;
	}
elsif ($in{'new'}) {
	# creating a new boot partition
	$other = { 'name' => 'other',
		   'members' => [ ] };
	}
else {
	# updating an existing image
	$oldother = $other = $conf->[$in{'idx'}];
	}

# Validate and store inputs
$in{'label'} =~ /\S+/ || &error($text{'other_ename'});
&save_subdirective($other, "label", $in{'label'});
$other->{'value'} = $in{'other'};
if ($in{'tablemode'} == 0) {
	&save_subdirective($other, "table");
	}
else {
	&save_subdirective($other, "table", $in{'table'});
	}
if ($in{'passmode'} == 0) {
	&save_subdirective($other, "password");
	}
else {
	&save_subdirective($other, "password", $in{'password'});
	}

# Save the actual partition structure
&save_directive($conf, $oldother, $other);
&flush_file_lines();
&unlock_file($config{'lilo_conf'});
&webmin_log($in{'new'} ? 'create' : 'modify', "other",
	    &find_value("label", $other->{'members'}), \%in);
&redirect("");

