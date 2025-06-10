#!/usr/local/bin/perl
# setup.cgi
# Actually setup SpamAssassin for the user or globally

require './spam-lib.pl';
&error_setup($text{'setup_err'});
&can_use_check("setup");
&ReadParse();

# Validate inputs
$type = undef;
if ($in{'to'} == 0) {
	$file = "/dev/null";
	}
elsif ($in{'to'} == 1) {
	$in{'mbox'} =~ /^\S+$/ || &error($text{'setup_efile'});
	$file = $in{'mbox'};
	}
elsif ($in{'to'} == 2) {
	$in{'maildir'} =~ /^\S+$/ || &error($text{'setup_emaildir'});
	$file = "$in{'maildir'}/";
	}
elsif ($in{'to'} == 3) {
	$in{'mhdir'} =~ /^\S+$/ || &error($text{'setup_emhdir'});
	$file = "$in{'mhdir'}/.";
	}
elsif ($in{'to'} == 4) {
	$file = "\$DEFAULT";
	}
elsif ($in{'to'} == 5) {
	$in{'email'} =~ /^\S+$/ || &error($text{'setup_eemail'});
	$file = $in{'email'};
	$type = "!";
	}

if ($module_info{'usermin'} && $file !~ /^\//) {
	# Create parent directory if needed
	if ($file =~ /^(\S+)\/([^\/]+)(\/(\.)?)?$/ &&
	    !-d "$remote_user_info[7]/$1") {
		&system_logged("mkdir -p '$remote_user_info[7]/$1'");
		}
	}

# Add template procmail rules
&foreign_require("procmail", "procmail-lib.pl");
@pmrc = &get_procmailrc();
if (!-s $pmrc[0] && $config{'extra_procmail'}) {
	&open_tempfile(PMRC, ">$pmrc[0]");
	&print_tempfile(PMRC, map { "$_\n" } split(/\t/, $config{'extra_procmail'}));
	&close_tempfile(PMRC);
	}

# Add new Procmail directives at the top of config file
$pmrc = $pmrc[$#pmrc];
@recipes = &procmail::parse_procmail_file($pmrc);
if ($in{'drop'}) {
	# Environment variable to drop privileges
	$recipe0 = { 'name' => 'DROPPRIVS',
		     'value' => 'yes' };
	}
if ($config{'call_spam'} || !$module_info{'usermin'}) {
	# Recipe to call spamassassin
	$recipe1 = { 'flags' => [ 'f', 'w' ],
		     'conds' => [ ],
		     'type' => '|',
		     'action' => &get_procmail_command() };
	}
if ($file) {
	# Recipe to perform actual filtering to a file
	$recipe2 = { 'flags' => [ ],
		     'conds' => [ [ '', '^X-Spam-Status: Yes' ] ],
		     'type' => $type,
		     'action' => $file };
	}
&lock_file($pmrc);
if (@recipes) {
	# Insert at start of file
	&procmail::create_recipe_before($recipe0, $recipes[0], $pmrc)
		if ($recipe0);
	&procmail::create_recipe_before($recipe1, $recipes[0], $pmrc)
		if ($recipe1);
	&procmail::create_recipe_before($recipe2, $recipes[0], $pmrc)
		if ($recipe2);
	}
else {
	# Just add to file
	&procmail::create_recipe($recipe0, $pmrc) if ($recipe0);
	&procmail::create_recipe($recipe1, $pmrc) if ($recipe1);
	&procmail::create_recipe($recipe2, $pmrc) if ($recipe2);
	}
chmod(0644, $pmrc);
&unlock_file($pmrc);

if ($module_info{'usermin'} && $file ne "/dev/null") {
	# Remember spam mail file
	$userconfig{'spam_file'} = $file;
	&write_file("$user_module_config_directory/config", \%userconfig);
	}

# All done!
&webmin_log("setup");
&redirect("");

