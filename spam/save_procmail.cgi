#!/usr/local/bin/perl
# Change the procmail rule that delivers spam

require './spam-lib.pl';
&error_setup($text{'procmail_err'});
&ReadParse();
&set_config_file_in(\%in);
&can_use_check("procmail");

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

# Find the existing recipe
&foreign_require("procmail", "procmail-lib.pl");
@pmrcs = &get_procmailrc();
$pmrc = $pmrcs[$#pmrcs];
@recipes = &procmail::parse_procmail_file($pmrc);
$spamrec = &find_file_recipe(\@recipes);

&lock_file($pmrc);
if ($file) {
	if ($spamrec) {
		# Update the recipe
		$spamrec->{'action'} = $file;
		$spamrec->{'type'} = $type;
		&procmail::modify_recipe($spamrec);
		}
	else {
		# Add a new recipe
		$spamrec = { 'flags' => [ ],
			     'conds' => [ [ '', '^X-Spam-Status: Yes' ] ],
			     'type' => $type,
			     'action' => $file };
		&procmail::create_recipe($spamrec, $pmrc);
		}
	}
elsif ($spamrec) {
	# Remove the recipe, to fall back to default delivery
	&procmail::delete_recipe($spamrec);
	}
&unlock_file($pmrc);

if ($module_info{'usermin'} && $file ne "/dev/null") {
	# Remember spam mail file
	$userconfig{'spam_file'} = $file;
	&write_file("$user_module_config_directory/config", \%userconfig);
	}

# All done!
&webmin_log("procmail");
&redirect($redirect_url);

