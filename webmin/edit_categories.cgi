#!/usr/local/bin/perl
# Show a form for editing custom category names

require './webmin-lib.pl';
ReadParse();
ui_print_header(undef, $text{'categories_title'}, undef);

# Show language selector
print ui_form_start("edit_categories.cgi");
print "<b>$text{'categories_lang'}</b>\n";
print ui_select("lang", $in{'lang'},
	[ [ "", "&lt;$text{'default'}&gt;" ],
	  map { [ $_->{'lang'}, "$_->{'desc'} (".uc($_->{'lang'}).")" ] }
	      list_languages() ]),"\n";
print ui_submit($text{'categories_langok'}),"\n";
print ui_form_end();

print "$text{'categories_desc'}<p>\n";
print ui_form_start("save_categories.cgi");
print ui_hidden("lang", $in{'lang'});
print ui_table_start($text{'categories_header'});

# Show the existing categories
$file = "$config_directory/webmin.catnames";
$file .= ".".$in{'lang'} if ($in{'lang'});
read_file($file, \%catnames);
foreach $t (keys %text) {
	$t =~ s/^category_// || next;
	print "<tr> <td><b>",$t ? $t : "<i>other</i>","</b></td>\n";
	printf "<td><input type=radio name=def_$t value=1 %s> %s (%s)</td>\n",
		$catnames{$t} ? '' : 'checked', $text{'default'},
		$text{"category_$t"};
	printf "<td><input type=radio name=def_$t value=0 %s> %s\n",
		$catnames{$t} ? 'checked' : '';
	printf "<input name=desc_$t size=30 value='%s'></td> </tr>\n",
		$catnames{$t};
	$realcat{$t}++;
	}
print "<tr> <td colspan=3><hr></td> </tr>\n";

# Show new categories
print "<tr> <td><b>$text{'categories_code'}</b></td> ",
      "<td colspan=2><b>$text{'categories_name'}</b></td> </tr>\n";
$i = 0;
foreach $c (keys %catnames) {
	if (!$realcat{$c}) {
		print "<tr> <td><input name=cat_$i size=10 value='$c'></td>\n";
		print "<td colspan=2><input name=desc_$i size=30 ",
		      "value='$catnames{$c}'></td> </tr>\n";
		$i++;
		}
	}
print "<tr> <td><input name=cat_$i size=10></td>\n";
print "<td colspan=2><input name=desc_$i size=30></td> </tr>\n";

print ui_table_end();
print ui_form_end([ [ "ok", $text{'categories_ok'} ] ]);
ui_print_footer("", $text{'index_return'});

