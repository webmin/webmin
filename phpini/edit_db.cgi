#!/usr/local/bin/perl
# Show options related to MySQL and other database connections

require './phpini-lib.pl';
&ReadParse();
&can_php_config($in{'file'}) || &error($text{'list_ecannot'});
$conf = &get_config($in{'file'});

&ui_print_header("<tt>$in{'file'}</tt>", $text{'db_title'}, "");
@tds = ( "width=30%" );

print &ui_form_start("save_db.cgi", "post");
print &ui_hidden("file", $in{'file'}),"\n";

# First section is for MySQL options
print &ui_table_start($text{'db_header1'}, "width=100%", 2);

# Allow persistent MySQL connections
print &ui_table_row($text{'db_persist'},
	    &onoff_radio("mysql.allow_persistent"),
	    undef, \@tds);

# Max persistent connections
$mp = &find_value("mysql.max_persistent", $conf);
print &ui_table_row($text{'db_maxpersist'},
	    &ui_opt_textbox("mysql.max_persistent", $mp <= 0 ? undef : $mp,
			    5, $text{'db_unlimited'}),
	    undef, \@tds);

# Max total connections
$mp = &find_value("mysql.max_links", $conf);
print &ui_table_row($text{'db_maxlinks'},
	    &ui_opt_textbox("mysql.max_links", $mp <= 0 ? undef : $mp,
			    5, $text{'db_unlimited'}),
	    undef, \@tds);

# Connection timeout
$ct = &find_value("mysql.connect_timeout", $conf);
print &ui_table_row($text{'db_timeout'},
	    &ui_opt_textbox("mysql.connect_timeout", $ct <= 0 ? undef : $ct,
			    5,$text{'default'})." ".$text{'db_s'},
	    undef, \@tds);

# Default host
print &ui_table_row($text{'db_host'},
	    &ui_opt_textbox("mysql.default_host",
			    &find_value("mysql.default_host", $conf),
			    30, "<tt>localhost</tt>"),
	    undef, \@tds);

# Default port
print &ui_table_row($text{'db_port'},
	    &ui_opt_textbox("mysql.default_port",
			    &find_value("mysql.default_port", $conf),
			    5, "<tt>3306</tt>"),
	    undef, \@tds);

print &ui_table_end();


# Second section is for PostgreSQL options
print &ui_table_start($text{'db_header2'}, "width=100%", 2);

# Allow persistent PostgreSQL connections
print &ui_table_row($text{'db_persist'},
	    &onoff_radio("pgsql.allow_persistent"),
	    undef, \@tds);

# Re-open persistent PostgreSQL connections
print &ui_table_row($text{'db_reset'},
	    &onoff_radio("pgsql.auto_reset_persistent"),
	    undef, \@tds);

# Max persistent connections
$mp = &find_value("pgsql.max_persistent", $conf);
print &ui_table_row($text{'db_maxpersist'},
	    &ui_opt_textbox("pgsql.max_persistent", $mp <= 0 ? undef : $mp,
			    5, $text{'db_unlimited'}),
	    undef, \@tds);

# Max total connections
$mp = &find_value("pgsql.max_links", $conf);
print &ui_table_row($text{'db_maxlinks'},
	    &ui_opt_textbox("pgsql.max_links", $mp <= 0 ? undef : $mp,
			    5, $text{'db_unlimited'}),
	    undef, \@tds);


print &ui_table_end();

print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("list_ini.cgi?file=".&urlize($in{'file'}),
		 $text{'list_return'});
