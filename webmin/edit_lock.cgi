#!/usr/local/bin/perl
# Display the locking form

require './webmin-lib.pl';
&ui_print_header(undef, $text{'lock_title'}, "");

print $text{'lock_desc'},"<p>\n";

print &ui_form_start("change_lock.cgi", "post");
print &ui_table_start($text{'lock_header'}, undef, 2);

print &ui_table_row($text{'lock_mode'},
	&ui_radio("lockmode", int($gconfig{'lockmode'}),
		[ [ 0, $text{'lock_all'} ],
		  [ 1, $text{'lock_none'} ],
		  [ 2, $text{'lock_only'} ],
		  [ 3, $text{'lock_except'} ] ])."<br>\n".
	&ui_textarea("lockdirs",
		join("\n", split(/\t+/, $gconfig{'lockdirs'})), 10, 60));

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

print &ui_table_hr();

my @locks = &list_active_locks();
my @tds;
push(@tds, "width=5");
my $locked_content;
if (@locks) {
	my $now = time();
	$locked_content = &ui_form_start("kill_lock.cgi", "post");
	$locked_content .= &ui_columns_start(
		[ "", $text{'lock_pid'}, $text{'lock_cmd'},
		      $text{'lock_file'}, $text{'lock_age'} ]);
	foreach my $p (@locks) {
		foreach my $l (@{$p->{'locks'}}) {
			my $age = $now - $l->{'time'};
			if ($age < 2*60) {
				$age .= " ".$text{'lock_s'};
				}
			elsif ($age < 2*60*60) {
				$age = int($age/60)." ".$text{'lock_m'};
				}
			else {
				$age = int($age/60/60)." ".$text{'lock_h'};
				}
			my $cmd = $p->{'proc'}->{'args'};
			$locked_content .= &ui_checked_columns_row(
				[
					&foreign_available('proc') ?
						&ui_link("@{[&get_webprefix()]}/proc/edit_proc.cgi?$p->{'pid'}", $p->{'pid'}) :
						$p->{'pid'},
					"<tt>".&html_escape($cmd)."</tt>",
					"<tt>".&html_escape($l->{'lock'})."</tt>",
					$age
				], \@tds, "d", $p->{'pid'}.'-'.$l->{'num'});
			}
		}
	$locked_content .= &ui_columns_end();
	$locked_content .= &ui_form_end([ [ 'term', $text{'lock_term'} ],
			     [ 'kill', $text{'lock_kill'} ] ]);
	print &ui_details({
			'title' => $text{'lock_files'},
			'class' => 'default',
			'content' => "$text{'lock_msg'}<br>" . $locked_content,
			'html' => 1}, 1);
	}
else {
	print &ui_details({
			'title' => $text{'lock_nfiles'},
			'class' => 'default',
			'content' => $text{'lock_noneopen'},
			'html' => 1});
	}

&ui_print_footer("", $text{'index_return'});

