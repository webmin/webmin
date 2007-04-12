#!/usr/local/bin/perl
# save_title.cgi
# Save a boot menu option

require './grub-lib.pl';
&ReadParse();
$conf = &get_menu_config();
if (!$in{'new'}) {
	$old = $title = $conf->[$in{'idx'}];
	}
&error_setup($text{'title_err'});

if ($in{'delete'}) {
	# Just delete the title
	&save_directive($conf, $title, undef);
	}
else {
	# validate inputs
	$in{'title'} =~ /\S/ || &error($text{'title_etitle'});
	$in{'root_mode'} != 1 || $in{'other'} =~ /^\S+$/ ||
		&error($text{'title_eroot'});
	$in{'boot_mode'} != 2 || $in{'kernel'} =~ /\S/ ||
		&error($text{'title_ekernel'});
	$in{'boot_mode'} != 1 || $in{'chain_def'} || $in{'chain'} =~ /\S/ ||
		&error($text{'title_echain'});
	$in{'initrd_def'} || $in{'initrd'} =~ /\S/ ||
		&error($text{'title_einitrd'});

	# store inputs in title structure
	$title->{'name'} = 'title';
	$title->{'value'} = $in{'title'};
	local $r = $in{'noverify'} ? "rootnoverify" : "root";
	delete($title->{'root'});
	delete($title->{'rootnoverify'});
	if ($in{'root_mode'} == 1) {
		$title->{$r} = $in{'other'};
		}
	elsif ($in{'root_mode'} == 2) {
		$root = &linux_to_bios($in{'root'});
		$root || &error(&text('title_edev', $in{'root'}));
		$title->{$r} = $root;
		}
	delete($title->{'kernel'});
	delete($title->{'chainloader'});
	delete($title->{'initrd'});
	if ($in{'boot_mode'} == 2) {
		$title->{'kernel'} = $in{'kernel'};
		$title->{'kernel'} .= " $in{'args'}" if ($in{'args'});
		$title->{'initrd'} = $in{'initrd'} if (!$in{'initrd_def'});
		}
	elsif ($in{'boot_mode'} == 1) {
		$title->{'chainloader'} = $in{'chain_def'} ? '+1'
							   : $in{'chain'};
		}
	if ($in{'makeactive'}) {
		$title->{'makeactive'} = "";
		}
	else {
		delete($title->{'makeactive'});
		}
	if ($in{'lock'}) {
		$title->{'lock'} = "";
		}
	else {
		delete($title->{'lock'});
		}

	# create or update the title
	&save_directive($conf, $old, $title);
	}

&flush_file_lines();
&redirect("");

