#!/usr/local/bin/perl
# save_image.cgi

require './lilo-lib.pl';
&ReadParse();

&lock_file($config{'lilo_conf'});
$conf = &get_lilo_conf();
if ($in{'delete'}) {
	# deleting an existing image
	$image = $conf->[$in{'idx'}];
	&save_directive($conf, $image);
	&flush_file_lines();
	&unlock_file($config{'lilo_conf'});
	&webmin_log("delete", "image",
		    &find_value("label", $image->{'members'}), \%in);
	&redirect("");
	exit;
	}
elsif ($in{'new'}) {
	# creating a new kernel image
	$image = { 'name' => 'image',
		   'members' => [ ] };
	}
else {
	# updating an existing image
	$oldimage = $image = $conf->[$in{'idx'}];
	}

# Validate and store inputs
$in{'label'} =~ /\S+/ || &error($text{'image_ename'});
&save_subdirective($image, "label", $in{'label'});
$in{'optional'} || -r $in{'image'} ||
	&error(&text('image_ekernel', $in{'image'}));
$image->{'value'} = $in{'image'};
if ($in{'opts'} == 0) {
	&save_subdirective($image, "append");
	&save_subdirective($image, "literal");
	}
elsif ($in{'opts'} == 1) {
	&save_subdirective($image, "append", "\"$in{'append'}\"");
	&save_subdirective($image, "literal");
	}
else {
	&save_subdirective($image, "append");
	&save_subdirective($image, "literal", "\"$in{'append'}\"");
	}
if ($in{'rmode'} == 0) {
	&save_subdirective($image, "root");
	}
elsif ($in{'rmode'} == 1) {
	&save_subdirective($image, "root", "current");
	}
elsif ($in{'rmode'} == 2) {
	&save_subdirective($image, "root", $in{'root'});
	}
if ($in{'initrd_def'}) {
	&save_subdirective($image, "initrd");
	}
else {
	-r $in{'initrd'} || &error(&text('image_einitrd', $in{'initrd'}));
	&save_subdirective($image, "initrd", $in{'initrd'});
	}
&save_subdirective($image, "read-only", $in{'ro'} == 1 ? "" : undef);
&save_subdirective($image, "read-write", $in{'ro'} == 2 ? "" : undef);
if ($in{'vga'} eq "") {
	&save_subdirective($image, "vga");
	}
elsif ($in{'vga'} eq "other") {
	$in{'vgaother'} =~ /^\d+$/ ||
		&error("VGA text mode must be an integer");
	&save_subdirective($image, "vga", $in{'vgaother'});
	}
else {
	&save_subdirective($image, "vga", $in{'vga'});
	}
if ($in{'passmode'} == 0) {
	&save_subdirective($image, "password");
	}
else {
	&save_subdirective($image, "password", $in{'password'});
	}
&save_subdirective($image, "restricted", $in{'restricted'} ? "" : undef);
&save_subdirective($image, "lock", $in{'lock'} ? "" : undef);
&save_subdirective($image, "optional", $in{'optional'} ? "" : undef);

# Save the actual image structure
&save_directive($conf, $oldimage, $image);
&flush_file_lines();
&unlock_file($config{'lilo_conf'});
&webmin_log($in{'new'} ? 'create' : 'modify', "image",
	    &find_value("label", $image->{'members'}), \%in);
&redirect("");

