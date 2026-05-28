#!/usr/local/bin/perl
# Generate the GRUB 2 menu file after a successful test generation.

use strict;
use warnings;
require './grub2-lib.pl';    ## no critic

our (%in, %text);

&ReadParse();
&error_setup($text{'generate_err'});
&grub2_assert_acl('apply');

my $return_url = $in{'redir'} || "index.cgi";
my ($current_step, $failed_printed, $failure_output_shown, $command_output) =
	('', 0, 0, '');

&ui_print_unbuffered_header(undef, $text{'generate_title'}, "");

# The generator emits coarse events so failures can show the right phase.
my $callback = sub {
	my ($event, $value) = @_;
	if ($event eq 'command') {
		# Capture the command text and all output for a single disclosure block.
		$current_step = 'command';
		$command_output = $value."\n";
		&print_step_start($text{'generate_regenerating'});
		return;
		}
	if ($event eq 'output') {
		$command_output .= $value;
		return;
		}
	if ($event eq 'command_done') {
		# Successful generation keeps noisy mkconfig output collapsed.
		&print_step_output($text{'generate_done'}, $command_output);
		$current_step = '';
		return;
		}
	if ($event eq 'command_failed') {
		# On command failure the captured output is the most useful detail.
		&print_step_output($text{'generate_failed_status'},
				    $command_output);
		$current_step = '';
		$failed_printed = 1;
		$failure_output_shown = 1;
		return;
		}
	if ($event eq 'check') {
		# The generated temporary grub.cfg is syntax-checked before replace.
		$current_step = 'check';
		&print_step_start($text{'generate_check'});
		return;
		}
	if ($event eq 'check_done') {
		&print_step_done(\$current_step);
		return;
		}
	if ($event eq 'check_failed') {
		&print_step_failed(\$current_step, \$failed_printed);
		return;
		}
	if ($event eq 'replace') {
		# Replacement only happens after a successful generation and check.
		$current_step = 'replace';
		&print_step_start($text{'generate_replace'});
		return;
		}
	if ($event eq 'replace_done') {
		&print_step_done(\$current_step);
		return;
		}
	};

my $err = &grub2_generate_config($callback);
if ($err) {
	# If the command output was not already shown, print the returned error.
	&print_step_failed(\$current_step, \$failed_printed)
		if ($current_step);
	&print_step_output($text{'generate_failed_status'}, $err)
		if (!$failure_output_shown);
	}
else {
	&grub2_mark_generated();
	&webmin_log("generate", undef, &grub2_config_value('grub_cfg'));
	}

&ui_print_footer($return_url, $text{'generate_return'});

# print_step_start(text)
# Prints the first progress line for one generation step.
sub print_step_start
{
my ($msg) = @_;
print &ui_tag('span', &html_escape($msg." .."),
	      { 'data-first-print' => undef });
print "<br>\n";
return;
}

# print_step_output(status, output)
# Prints command output inside an inline details disclosure.
sub print_step_output
{
my ($status, $output) = @_;
$output = '' if (!defined($output));
print &ui_details({
	'html' => 1,
	'title' => &ui_tag('span', &html_escape(".. ".$status),
			   { 'data-second-print' => undef }),
	'content' => &ui_tag('pre', &html_escape($output),
			     { 'style' => 'margin-left: 10px;' }),
	'class' => 'inline inlined',
	});
print "<div data-x-br=\"\"></div>\n";
return;
}

# print_step_done(&current-step)
# Prints a successful progress line and clears the active step.
sub print_step_done
{
my ($current) = @_;
print &ui_tag('span', &html_escape(".. ".$text{'generate_done'}),
	      { 'data-second-print' => undef });
print "<br><div data-x-br=\"\"></div>\n";
$$current = '';
return;
}

# print_step_failed(&current-step, &printed-flag)
# Prints a failed progress line once and clears the active step.
sub print_step_failed
{
my ($current, $printed) = @_;
return if ($$printed);
print &ui_tag('span', &html_escape(".. ".$text{'generate_failed_status'}),
	      { 'data-second-print' => undef });
print "<br><div data-x-br=\"\"></div>\n";
$$current = '';
$$printed = 1;
return;
}
