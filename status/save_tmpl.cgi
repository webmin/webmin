#!/usr/local/bin/perl
# Create, update or delete a template

require './status-lib.pl';
$access{'edit'} || &error($text{'tmpls_ecannot'});
&ReadParse();
&error_setup($text{'tmpl_err'});

# Get the template
if (!$in{'new'}) {
	$tmpl = &get_template($in{'id'});
	}
else {
	$tmpl = { };
	}

if ($in{'delete'}) {
	# Remove this template
	&delete_template($tmpl);
	&webmin_log("delete", "template", $tmpl->{'desc'});
	}
else {
	# Validate and store inputs
	$in{'desc'} =~ /\S/ || &error($text{'tmpl_edesc'});
	$tmpl->{'desc'} = $in{'desc'};
	$in{'msg'} =~ /\S/ || &error($text{'tmpl_emsg'});
	$tmpl->{'msg'} = $in{'msg'};
	if ($in{'sms_def'}) {
		delete($tmpl->{'sms'});
		}
	else {
		$in{'sms'} =~ /\S/ || &error($text{'tmpl_esms'});
		$tmpl->{'sms'} = $in{'sms'};
		}
	if ($in{'pager_def'}) {
		delete($tmpl->{'pager'});
		}
	else {
		$in{'pager'} =~ /\S/ || &error($text{'tmpl_epager'});
		$tmpl->{'pager'} = $in{'pager'};
		}

	# Save or create
	&save_template($tmpl);
	&webmin_log($in{'new'} ? "create" : "modify", "template",
		    $tmpl->{'desc'});
	}
&redirect("list_tmpls.cgi");

