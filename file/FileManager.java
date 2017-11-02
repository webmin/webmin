import java.awt.*;
import java.awt.event.*;
import java.io.*;
import java.applet.*;
import java.net.*;
import java.util.*;
import netscape.javascript.JSObject;

// A java filemanager that allows the user to manipulate files on the
// Webmin server. Layout is similar to the windows explorer - directory
// tree on the left, files on the right, action buttons on the top.
public class FileManager extends Applet
	implements CbButtonCallback, HierarchyCallback, MultiColumnCallback
{
	// top buttons
	CbButton ret_b, config_b, down_b, edit_b, refresh_b, props_b,
		 copy_b, cut_b, paste_b, delete_b, new_b, upload_b, mkdir_b,
		 makelink_b, rename_b, share_b, mount_b, search_b, acl_b,
		 attr_b, ext_b, preview_b, extract_b, hnew_b;

	// Directory tree
	Hierarchy dirs;
	FileNode root;
	Hashtable nodemap = new Hashtable();

	// File list
	MultiColumn files;
	TextField pathname;
	CbButton history_b;
	RemoteFile showing_files;
	RemoteFile showing_list[];
	Vector history_list = new Vector();

	// Copying and pasting
	RemoteFile cut_buffer[];
	boolean cut_mode;

	static final String monmap[] = { "Jan", "Feb", "Mar", "Apr",
					 "May", "Jun", "Jul", "Aug",
					 "Sep", "Oct", "Nov", "Dec" };
	String accroot[];
	String accnoroot[];
	Hashtable lang = new Hashtable();
	Hashtable stab = new Hashtable(),
		  ntab = new Hashtable();
	boolean sambamode;
	int nfsmode;
	String trust;
	String extra;
	String images;
	int iconsize;

	boolean got_filesystems,
		acl_support, attr_support, ext_support;
	Hashtable mounts = new Hashtable();
	Vector fslist = new Vector();
	boolean read_only = false;

	// Standard font for all text
	Font fixed;

	// Font for button labels
	Font small_fixed;

	// Full session cookie
	String session;

	// HTTP referer
	String referer;

	// Archive parameter
	String archive;

	// Chroot directory for tree
	String chroot;

	// File attributes that can be edited
	boolean can_perms, can_users;

	// Symlimks are automatically followed
	boolean follow_links;

	// Can search file contents
	boolean search_contents;

	// Use text editor for HTML
	boolean force_text;

	// File extensions to consider as HTML
	String htmlexts[];

	public void init()
	{
	setLayout(new BorderLayout());

	// Create fonts from specified size
	fixed = make_font("fixed", 12);
	small_fixed = make_font("small_fixed", 10);

	Util.setFont(small_fixed);
	StringTokenizer tok = new StringTokenizer(getParameter("root"), " ");
	accroot = new String[tok.countTokens()];
	for(int i=0; tok.hasMoreTokens(); i++)
		accroot[i] = tok.nextToken();
	if (getParameter("noroot") != null) {
		tok = new StringTokenizer(getParameter("noroot"), " ");
		accnoroot = new String[tok.countTokens()];
		for(int i=0; tok.hasMoreTokens(); i++)
			accnoroot[i] = tok.nextToken();
		}
	else {
		accnoroot = new String[0];
		}
	trust = getParameter("trust");
	session = getParameter("session");
	referer = getDocumentBase().toString();
	extra = getParameter("extra");
	if (extra == null) extra = "";
	images = getParameter("images");
	if (images == null) images = "images";
	iconsize = Integer.parseInt(getParameter("iconsize"));
	archive = getParameter("doarchive");
	if (archive == null) archive = "0";
	chroot = getParameter("chroot");
	if (chroot == null) chroot = "/";
	String can_perms_str = getParameter("canperms");
	can_perms = can_perms_str == null || !can_perms_str.equals("0");
	String can_users_str = getParameter("canusers");
	can_users = can_users_str == null || !can_users_str.equals("0");
	String search_contents_str = getParameter("contents");
	search_contents = search_contents_str == null ||
			  !search_contents_str.equals("0");
	String force_text_str = getParameter("force_text");
	if (force_text_str != null && force_text_str.equals("1"))
		force_text = true;
	String htmlexts_str = getParameter("htmlexts");
	if (htmlexts_str == null || htmlexts_str.equals(""))
		htmlexts_str = ".htm .html";
	htmlexts = DFSAdminExport.split(htmlexts_str);

	// download language strings
	String l[] = get_text("lang.cgi");
	if (l.length < 1 || l[0].indexOf('=') < 0) {
		String err = "Failed to get language list : "+join_array(l);
		new ErrorWindow(err);
		throw new Error(err);
		}
	for(int i=0; i<l.length; i++) {
		int eq = l[i].indexOf('=');
		if (eq >= 0)
			lang.put(l[i].substring(0, eq), l[i].substring(eq+1));
		}

	// list samba file shares
	String s[] = get_text("list_shares.cgi");
	if (s[0].equals("1")) {
		for(int i=1; i<s.length; i++) {
			SambaShare ss = new SambaShare(s[i]);
			stab.put(ss.path, ss);
			}
		sambamode = true;
		}

	// list NFS exports
	String e[] = get_text("list_exports.cgi");
	nfsmode = e.length == 0 ? 0 : Integer.parseInt(e[0]);
	if (nfsmode != 0) {
		for(int i=1; i<e.length; i++) {
			if (nfsmode == 1) {
				// Linux export
				LinuxExport le = new LinuxExport(e[i]);
				ntab.put(le.path, le);
				}
			else if (nfsmode == 2) {
				// Solaris share
				DFSAdminExport de = new DFSAdminExport(e[i]);
				ntab.put(de.path, de);
				}
			}
		}

	// list filesystems
	get_filesystems();

	// get read-only flag
	if (getParameter("ro").equals("1"))
		read_only = true;

	// get custom colours
	Util.light_edge = get_colour("light_edge", Util.light_edge);
	Util.dark_edge = get_colour("dark_edge", Util.dark_edge);
	Util.body = get_colour("body", Util.body);
	Util.body_hi = get_colour("body_hi", Util.body_hi);
	Util.light_edge_hi = get_colour("light_edge_hi", Util.light_edge_hi);
	Util.dark_edge_hi = get_colour("dark_edge_hi", Util.dark_edge_hi);
	Util.dark_bg = get_colour("dark_bg", Util.dark_bg);
	Util.text = get_colour("text", Util.text);
	Util.light_bg = get_colour("light_bg", Util.light_bg);

	// create button panel
	BorderPanel top = new BorderPanel(2, Util.body);
	top.setLayout(new ToolbarLayout(ToolbarLayout.LEFT, 5, 2));

	Panel top1 = new Panel();
	top1.setLayout(new GridLayout(1, 0));
	if (getParameter("return") != null && can_button("return"))
		top1.add(ret_b = make_button("ret.gif", text("top_ret")));
	if (getParameter("config") != null && can_button("config"))
		top1.add(config_b = make_button("config.gif",
						text("top_config")));
	if (can_button("save"))
		top1.add(down_b = make_button("down.gif", text("top_down")));
	if (can_button("preview"))
		top1.add(preview_b = make_button("preview.gif", text("top_preview")));
	if (!read_only && can_button("edit")) {
		top1.add(edit_b = make_button("edit.gif", text("top_edit")));
		}
	if (can_button("refresh"))
		top1.add(refresh_b = make_button("refresh.gif", text("top_refresh")));
	if (!read_only && can_button("info"))
		top1.add(props_b = make_button("props.gif", text("top_info")));
	if (acl_support && !read_only && can_button("acl"))
		top1.add(acl_b = make_button("acl.gif", text("top_eacl")));
	if (attr_support && !read_only && can_button("attr"))
		top1.add(attr_b = make_button("attr.gif", text("top_attr")));
	if (ext_support && !read_only && can_button("ext"))
		top1.add(ext_b = make_button("ext.gif", text("top_ext")));
	if (can_button("search"))
		top1.add(search_b = make_button("search.gif", text("top_search")));
	top.add(top1);
	
	if (!read_only) {
		Panel top2 = new Panel();
		top2.setLayout(new GridLayout(1, 0));
		if (can_button("delete"))
			top2.add(delete_b = make_button("delete.gif",
							text("top_delete")));
		if (can_button("new")) {
			top2.add(new_b = make_button("new.gif",
						     text("top_new")));
			if (can_button("htmlnew"))
				top2.add(hnew_b = make_button("html.gif",
							     text("top_new")));
			}
		if (can_button("upload"))
			top2.add(upload_b = make_button("upload.gif",
							text("top_upload")));
		if (can_button("extract"))
			top2.add(extract_b = make_button("extract.gif",
							 text("top_extract")));
		if (can_button("mkdir"))
			top2.add(mkdir_b = make_button("mkdir.gif",
						       text("top_new")));
		if (getParameter("follow").equals("0") &&
		    can_button("makelink"))
			top2.add(makelink_b = make_button("makelink.gif",
						text("top_new")));
		if (can_button("rename"))
			top2.add(rename_b = make_button("rename.gif",
							text("top_rename")));
		if ((sambamode || nfsmode != 0) &&
		    getParameter("sharing").equals("1") &&
		    can_button("sharing"))
			top2.add(share_b = make_button("share.gif",
						       text("top_share")));
		if (getParameter("mounting").equals("1") &&
		    can_button("mount"))
			top2.add(mount_b = make_button("mount.gif",
						       text("top_mount")));
		top.add(top2);

		if (can_button("copy")) {
			Panel top3 = new Panel();
			top3.setLayout(new GridLayout(1, 0));
			top3.add(copy_b = make_button("copy.gif",
						      text("top_copy")));
			top3.add(cut_b = make_button("cut.gif",
						     text("top_cut")));
			top3.add(paste_b = make_button("paste.gif",
						       text("top_paste")));
			top.add(top3);
			}
		}
	add("North", top);
	follow_links = getParameter("follow").equals("1");

	// create directory tree
	BorderPanel left = new BorderPanel(2, Util.body);
	left.setLayout(new BorderLayout());
	root = new FileNode(new RemoteFile(this, get_text("root.cgi")[0],null));
	left.add("Center", dirs = new Hierarchy(root, this));
	dirs.setFont(fixed);
	root.open = true; root.fill();

	// create file list window
	BorderPanel right = new BorderPanel(2, Util.body);
	right.setLayout(new BorderLayout());
	Panel rtop = new Panel();
	rtop.setLayout(new BorderLayout());
	rtop.add("Center", pathname = new TextField());
	rtop.add("East", history_b = new CbButton(text("history_button"),this));
	right.add("North", rtop);
	pathname.setFont(fixed);
	String cols[] = { "", text("right_name"), text("right_size"),
			  text("right_user"), text("right_group"),
			  text("right_date") };
	float widths[] = { .07f, .33f, .15f, .15f, .15f, .15f };
	right.add("Center", files = new MultiColumn(cols, this));
	files.setWidths(widths);
	files.setDrawLines(false);
	files.setMultiSelect(true);
	files.setFont(fixed);
	show_files(root.file);

	ResizePanel mid = new ResizePanel(left, right, .3, false);
	add("Center", mid);

	// Go to the restricted directory
	String home = getParameter("home");
	String go = getParameter("goto");
	String open = getParameter("open");
	if (open != null) {
		find_directory(open, true);
		}
	else if (go != null && go.equals("1")) {
		if (home != null)
			find_directory(home, true);
		else if (!accroot[0].equals("/"))
			find_directory(accroot[0], true);
		}
	}

	Font make_font(String name, int defsize)
	{
	String str = getParameter(name);
	int size = str == null || str.equals("") ? defsize :
		   Integer.parseInt(str);
	return new Font("courier", Font.PLAIN, size);
	}

	// Looks up an applet parameter for a colour, and returns it if
	// defined, otherwise the default. MUST	be in RRGGBB hex format
	Color get_colour(String name, Color def)
	{
	String str = getParameter("applet_"+name);
	if (str == null) {
		return def;
		}
	else {
		return new Color(get_hex(str, 0),
				 get_hex(str, 2),
				 get_hex(str, 4));
		}
	}

	int get_hex(String str, int pos)
	{
	str = str.toUpperCase();
	char c1 = str.charAt(pos), c2 = str.charAt(pos+1);
	int b1 = Character.isDigit(c1) ? c1-48 : c1-65+10;
	int b2 = Character.isDigit(c2) ? c2-48 : c2-65+10;
	return (b1<<4) + (b2);
	}

	boolean can_button(String name)
	{
	return getParameter("no_"+name) == null;
	}

	CbButton make_button(String f, String t)
	{
	if (iconsize == 1)
		return new CbButton(get_image(f), this);
	else
		return new CbButton(get_image(f), t, CbButton.ABOVE, this);
	}

	// Gets an image from the images directory
	Image get_image(String img)
	{
	return getImage(getDocumentBase(), images+"/"+img);
	}

	// Gets charset parameter from Content-Type: header
	String get_charset(String ct)
	{
	if (ct == null)
		return null;
	StringTokenizer st = new StringTokenizer(ct, ";");
	while (st.hasMoreTokens()) {
		String l = st.nextToken().trim();
		if (l.startsWith("charset=")) {
			// get the value of charset= param.
			return l.substring(8);
			}
		}
	return null;
	}

	String[] get_text(String url)
	{
	try {
		long now = System.currentTimeMillis();
		if (url.indexOf('?') > 0) url += "&rand="+now;
		else url += "?rand="+now;
		url += "&trust="+trust;
		url += extra;
		URL u = new URL(getDocumentBase(), url);
		URLConnection uc = u.openConnection();
		set_cookie(uc);
		String charset = get_charset(uc.getContentType());
		InputStream ris = uc.getInputStream();
		BufferedReader is = null;
		if (charset == null) {
			is = new BufferedReader(new InputStreamReader(ris));
			}
		else {
			// Try to use a character set, and handle failure
			try {
				is = new BufferedReader(
					new InputStreamReader(ris, charset));
				}
			catch(Exception e) {
				e.printStackTrace();
				is = new BufferedReader(
					new InputStreamReader(ris));
				}
			}
		Vector lv = new Vector();
		while(true) {
			String l = is.readLine();
			if (l == null) { break; }
			lv.addElement(l);
			}
		is.close();
		String rv[] = new String[lv.size()];
		lv.copyInto(rv);
		return rv;
		}
	catch(Exception e) {
		e.printStackTrace();
		//return null;
		String err[] = { e.getClass().getName()+" : "+e.getMessage() };
		return err;
		}
	}

	void set_cookie(URLConnection conn)
	{
	if (session != null)
		conn.setRequestProperty("Cookie", session);
	conn.setRequestProperty("Referer", referer);
	}

	// Fill the multicolumn list with files from some directory
	boolean show_files(RemoteFile f)
	{
	RemoteFile fl[] = f.list();
	if (fl == null) return false;
	files.clear();
	Object rows[][] = new Object[fl.length+1][];
	long now = System.currentTimeMillis();

	// Sort listing by chosen column
	if (f != showing_files) {
		// Directory has changed .. assume sort by name
		files.sortingArrow(1, 1);
		}
	else if (files.sortdir != 0) {
		// Sort by chosen order
		RemoteFile fls[] = new RemoteFile[fl.length];
		System.arraycopy(fl, 0, fls, 0, fl.length);
		QuickSort.sort(fls, files.sortcol, files.sortdir);
		fl = fls;
		}

	// Create parent directory row
	rows[0] = new Object[6];
	rows[0][0] = get_image("dir.gif");
	rows[0][1] = "..";
	rows[0][2] = rows[0][3] = rows[0][4] = rows[0][5] = "";

	// Create file rows
	Date n = new Date(now);
	for(int i=0; i<fl.length; i++) {
		Object row[] = rows[i+1] = new Object[6];
		if (fl[i].shared() && fl[i].mounted())
			row[0] = get_image("smdir.gif");
		else if (fl[i].shared() && fl[i].mountpoint())
			row[0] = get_image("sudir.gif");
		else if (fl[i].shared())
			row[0] = get_image("sdir.gif");
		else if (fl[i].mounted())
			row[0] = get_image("mdir.gif");
		else if (fl[i].mountpoint())
			row[0] = get_image("udir.gif");
		else
			row[0] = get_image(RemoteFile.tmap[fl[i].type]);
		row[1] = fl[i].name;
		if (fl[i].size < 1000)
			row[2] = spad(fl[i].size, 5)+" B";
		else if (fl[i].size < 1000000)
			row[2] = spad(fl[i].size/1000, 5)+" kB";
		else
			row[2] = spad(fl[i].size/1000000, 5)+" MB";
		row[3] = fl[i].user;
		row[4] = fl[i].group;
		Date d = new Date(fl[i].modified);
		//if (now - fl[i].modified < 24*60*60*1000) {
		if (n.getDate() == d.getDate() &&
		    n.getMonth() == d.getMonth() &&
		    n.getYear() == d.getYear()) {
			// show as hour:min
			row[5] = pad(d.getHours(),2)+":"+
				 pad(d.getMinutes(),2);
			}
		//else if (now - fl[i].modified < 24*60*60*365*1000) {
		else if (n.getYear() == d.getYear()) {
			// show as day/mon
			row[5] = pad(d.getDate(),2)+"/"+
				 monmap[d.getMonth()];
			}
		else {
			// show as mon/year
			row[5] = monmap[d.getMonth()]+"/"+
				 pad(d.getYear()%100, 2);
			}
		}
	files.addItems(rows);
	showing_files = f;
	showing_list = fl;
	pathname.setText(f.path);
	return true;
	}

	String pad(int n, int s)
	{
	String rv = String.valueOf(n);
	while(rv.length() < s)
		rv = "0"+rv;
	return rv;
	}

	String spad(long n, int s)
	{
	String rv = String.valueOf(n);
	while(rv.length() < s)
		rv = " "+rv;
	return rv;
	}

	String trim_path(String p)
	{
	while(p.endsWith("/"))
		p = p.substring(0, p.length()-1);
	return p;
	}

	// openNode
	// Called when a node with children is opened
	public void openNode(Hierarchy h, HierarchyNode n)
	{
	FileNode fn = (FileNode)n;
	fn.fill();
	}

	// closeNode
	// Called when a node is closed
	public void closeNode(Hierarchy h, HierarchyNode n)
	{
	}

	// clickNode
	// Called when the user clicks on a node
	public void clickNode(Hierarchy h, HierarchyNode n)
	{
	FileNode fn = (FileNode)n;
	if (showing_files != fn.file)
		show_files(fn.file);
	}

	// doubleNode
	// Called when a user double-clicks on a node
	public void doubleNode(Hierarchy h, HierarchyNode n)
	{
	}

	// Called when a button is clicked
	public void click(CbButton b)
	{
	int s = files.selected();
	int ss[] = files.allSelected();
	RemoteFile f = null, ff[] = new RemoteFile[0];
	if (s > 0 || s == 0 && ss.length > 1) {
		// At least one non-.. file was selected
		boolean parentsel = false;
		for(int i=0; i<ss.length; i++)
			if (ss[i] == 0)
				parentsel = true;
		RemoteFile list[] = showing_list;
		if (parentsel) {
			// need to exclude .. from selected list!
			ff = new RemoteFile[ss.length-1];
			for(int i=0,j=0; i<ss.length; i++)
				if (ss[i] != 0)
					ff[j++] = list[ss[i]-1];
			f = s == 0 ? ff[0] : list[s-1];
			}
		else {
			// include all selected files
			f = list[s-1];
			ff = new RemoteFile[ss.length];
			for(int i=0; i<ss.length; i++)
				ff[i] = list[ss[i]-1];
			}
		}
	FileNode d = (FileNode)dirs.selected();
	if (b == ret_b) {
		// Return to the webmin index
		try {
			URL u = new URL(getDocumentBase(),
					getParameter("return"));
			getAppletContext().showDocument(u);
			}
		catch(Exception e) { }
		}
	else if (b == config_b) {
		// Open the module config window
		try {
			URL u = new URL(getDocumentBase(),
					getParameter("config"));
			getAppletContext().showDocument(u, "_self");
			}
		catch(Exception e) { }
		}
	else if (b == edit_b) {
		// Open a window for editing the selected file
		if (f == null)
			new ErrorWindow(text("top_efile"));
		else if (f.type == 0 || f.type > 4)
			new ErrorWindow(text("edit_enormal"));
		else if (is_html_filename(f.path) && !force_text) {
			// Open HTML editor
			try {
				JSObject win = JSObject.getWindow(this);
				String params[] = { f.path, "" };
				win.call("htmledit", params);
				}
			catch(Exception e) {
				new ErrorWindow(text("html_efailed",
						     e.getMessage()));
				}
			}
		else {
			// Open text editor
			new EditorWindow(f, this);
			}
		}
	else if (b == down_b) {
		// Force download of the selected file
		if (f == null) return;
		download_file(f);
		}
	else if (b == preview_b) {
		// Open preview window for selected file
		if (f == null) return;
		if (f.type == RemoteFile.DIR)
			new ErrorWindow(text("preview_eimage"));
		else
			new PreviewWindow(this, f);
		}
	else if (b == refresh_b) {
		// Refesh the selected directory (and thus any subdirs)
		if (d == null) return;
		d.refresh();
		show_files(d.file);
		}
	else if (b == props_b) {
		// Display the properties window
		if (f == null) return;
		new PropertiesWindow(f, this);
		}
	else if (b == acl_b) {
		// Display the ACL window (if filesystem supports them)
		if (f == null) return;
		FileSystem filefs = find_filesys(f);
		if (filefs == null) return;
		if (filefs.acls)
			new ACLWindow(this, f);
		else
			new ErrorWindow(text("eacl_efs", filefs.mount));
		}
	else if (b == attr_b) {
		// Display the attributes window (if filesystem supports them)
		if (f == null) return;
		FileSystem filefs = find_filesys(f);
		if (filefs == null) return;
		if (filefs.attrs)
			new AttributesWindow(this, f);
		else
			new ErrorWindow(text("attr_efs", filefs.mount));
		}
	else if (b == ext_b) {
		// Display EXT attributes window (if filesystem supports them)
		if (f == null) return;
		FileSystem filefs = find_filesys(f);
		if (filefs == null) return;
		if (filefs.ext)
			new EXTWindow(this, f);
		else
			new ErrorWindow(text("ext_efs", filefs.mount));
		}
	else if (b == copy_b) {
		// Copy the selected files
		if (f == null) return;
		cut_buffer = ff;
		cut_mode = false;
		}
	else if (b == cut_b) {
		// Cut the selected file
		if (f == null) return;
		cut_buffer = ff;
		cut_mode = true;
		}
	else if (b == paste_b) {
		// Paste the copied file
		if (cut_buffer == null) {
			new ErrorWindow(text("paste_ecopy"));
			return;
			}

		// Check for existing file clashes
		// XXX

		// Go through all the files to paste
		for(int i=0; i<cut_buffer.length; i++) {
			RemoteFile cf = cut_buffer[i];

			// Check for an existing file
			RemoteFile already = showing_files.find(cf.name);
			String sp = showing_files.path;
			String dest_path = sp.equals("/") ? sp+cf.name
							  : sp+"/"+cf.name;
			if (already != null) {
				// File exists .. offer to rename
				new OverwriteWindow(this, already, cf, i);
				}
			else {
				// do the move or copy
				RemoteFile nf = paste_file(cf, showing_files,
						   dest_path, null, cut_mode);
				if (cut_mode && nf != null) {
					// Paste from the destination path
					// from now on
					cut_buffer[i] = nf;
					}
				}
			}
		cut_mode = false;
		}
	else if (b == delete_b) {
		// Delete the selected files
		if (f == null) return;
		new DeleteWindow(this, ff);
		}
	else if (b == new_b) {
		// Open a window for creating a text file
		new EditorWindow(showing_files.path, this);
		}
	else if (b == hnew_b) {
		// Open a window for creating an HTML file
		try {
			JSObject win = JSObject.getWindow(this);
			String params[] = { "", showing_files.path };
			win.call("htmledit", params);
			}
		catch(Exception e) {
			new ErrorWindow(text("html_efailed",
					     e.getMessage()));
			}
		}
	else if (b == upload_b) {
		// Call javascript to open an upload window
		try {
			JSObject win = JSObject.getWindow(this);
			String params[] = { showing_files.path };
			win.call("upload", params);
			}
		catch(Exception e) {
			new ErrorWindow(text("upload_efailed", e.getMessage()));
			}
		}
	else if (b == extract_b) {
		// Ask for confirmation, then extract file
		if (f == null) return;
		if (f.type == 0 || f.type == 6 || f.type == 7)
			new ErrorWindow(text("extract_etype", f.path));
		else
			new ExtractWindow(this, f);
		}
	else if (b == mkdir_b) {
		// Prompt for new directory
		new MkdirWindow(showing_files.path, this);
		}
	else if (b == makelink_b) {
		// Prompt for a new symlink
		new LinkWindow(showing_files.path, this);
		}
	else if (b == rename_b) {
		// Prompt for new filename
		if (f == null) return;
		new RenameWindow(this, f);
		}
	else if (b == share_b) {
		// Open a window for editing sharing options
		if (f == null || f.type != RemoteFile.DIR) return;
		new SharingWindow(f, this);
		}
	else if (b == mount_b) {
		// Check if the selected directory is a mount point
		if (f == null || f.type != RemoteFile.DIR) return;
		FileSystem fs = f.fs();
		if (fs == null)
			new ErrorWindow(text("mount_epoint", f.path));
		else
			new MountWindow(this, fs, f);
		}
	else if (b == search_b) {
		// Open window for finding a file
		new SearchWindow(showing_files.path, this);
		}
	else if (b == history_b) {
		// Open entered file history window
		if (history_list.size() > 0) {
			new HistoryWindow(this);
			}
		}
	}

	boolean is_html_filename(String path)
	{
	for(int i=0; i<htmlexts.length; i++)
		if (path.toLowerCase().endsWith(htmlexts[i]))
			return true;
	return false;
	}

	boolean under_root_dir(String p, String roots[])
	{
	boolean can = false;
	int l = p.length();
	for(int r=0; r<roots.length; r++) {
		int rl = roots[r].length();
		if (roots[r].equals("/"))
			can = true;
		else if (l >= rl && p.substring(0, rl).equals(roots[r]))
			can = true;
		else if (l < rl && roots[r].substring(0, l).equals(p))
			can = true;
		}
	return can;
	}

	// Download some file to the user's browser, if possible
	void download_file(RemoteFile f)
	{
	if (f.type == RemoteFile.DIR && !archive.equals("0"))
		new DownloadDirWindow(this, f);
	else if (f.type == RemoteFile.DIR || f.type > 4)
		new ErrorWindow(text("view_enormal2"));
	else
		open_file_window(f, true, 0);
	}

	// Returns the object for some directory, or null if not found.
	RemoteFile find_directory(String p, boolean fill)
	{
	boolean can = under_root_dir(p, accroot) &&
		      !under_root_dir(p, accnoroot);
	if (!can) {
		new ErrorWindow(text("find_eaccess", p));
		return null;
		}
	FileNode posnode = root;
	RemoteFile pos = posnode.file;
	StringTokenizer tok = new StringTokenizer(p, "/");
	while(tok.hasMoreTokens()) {
		String fn = tok.nextToken();
		if (fn.equals("")) continue;
		RemoteFile fl[] = pos.list();
		if (fl == null) return null;
		if (fill) {
			posnode.open = true;
			posnode.fill();
			}
		boolean found = false;
		for(int i=0; i<fl.length; i++)
			if (fl[i].name.equals(fn)) {
				pos = fl[i];
				found = true;
				}
		if (!found) {
			new ErrorWindow(text("find_eexist", fn, p));
			return null;
			}
		if (pos.type != 0) {
			new ErrorWindow(text("find_edir", fn, p));
			return null;
			}
		if (fill)
			posnode = (FileNode)nodemap.get(pos);
		}
	if (fill) {
		if (show_files(pos)) {
			posnode.fill();
			posnode.open = true;
			dirs.select(posnode);
			dirs.redraw();
			}
		}
	return pos;
	}

	FileSystem find_filesys(RemoteFile f)
	{
	FileSystem filefs = null;
	for(int i=0; i<fslist.size(); i++) {
		FileSystem fs = (FileSystem)fslist.elementAt(i);
		int l = fs.mount.length();
		if (fs.mount.equals(f.path) ||
		    (f.path.length() >= l+1 &&
		     f.path.substring(0, l+1).equals(fs.mount+"/")) ||
		    fs.mount.equals("/")) {
			filefs = fs;
			}
		}
	return filefs;
	}

	public boolean action(Event e, Object o)
	{
	if (e.target == pathname) {
		// A new path was entered.. cd to it
		String p = pathname.getText().trim();
		if (p.equals("")) return true;
		find_directory(p, true);

		// Add to the history
		if (!history_list.contains(p)) {
			history_list.insertElementAt(p, 0);
			}
		return true;
		}
	return false;
	}

        // singleClick
        // Called on a single click on a list item
        public void singleClick(MultiColumn list, int num)
	{
	}

        // doubleClick
        // Called upon double-clicking on a list item
        public void doubleClick(MultiColumn list, int num)
	{
	if (num == 0) {
		// Go to parent directory
		if (showing_files.directory != null) {
			((FileNode)nodemap.get(showing_files)).open = false;
			show_files(showing_files.directory);
			dirs.select((FileNode)nodemap.get(showing_files));
			dirs.redraw();
			}
		return;
		}
	RemoteFile d = showing_list[num-1];
	if (d.type == 0) {
		// Open this directory
		FileNode pn = (FileNode)nodemap.get(showing_files);
		pn.fill();
		pn.open = true;
		FileNode fn = (FileNode)nodemap.get(d);
		if (show_files(d)) {
			fn.fill();
			fn.open = true;
			dirs.select(fn);
			dirs.redraw();
			}
		}
	else if (d.type <= 4) {
		// Direct the browser to this file
		open_file_window(d, list.last_event.shiftDown(), 0);
		}
	}

	// Called when the user clicks on a column heading so that it can
	// be sorted.
	public void headingClicked(MultiColumn list, int col)
	{
	if (col == 0)
		return;	// ignore click on icon column?
	if (col == list.sortcol) {
		list.sortingArrow(col, list.sortdir == 2 ? 1 : 2);
		}
	else {
		list.sortingArrow(col, 1);
		}

	// Re-show the list in the new order, but with the same files selected
	int ss[] = files.allSelected();
	RemoteFile ssf[] = new RemoteFile[ss.length];
	for(int i=0; i<ss.length; i++)
		ssf[i] = showing_list[ss[i]-1];
	show_files(showing_files);
	for(int i=0; i<ss.length; i++) {
		for(int j=0; j<showing_list.length; j++) {
			if (showing_list[j] == ssf[i]) {
				ss[i] = j+1;
				break;
				}
			}
		}
	files.select(ss);
	}

	void open_file_window(RemoteFile f, boolean download, int format)
	{
	try {
		String ext = format == 1 ? ".zip" :
			     format == 2 ? ".tgz" :
			     format == 3 ? ".tar" : "";
		String urlstr;
		if (download) {
			urlstr = "show.cgi"+urlize(f.path)+ext+
				 "?rand="+System.currentTimeMillis()+
				 "&type=application%2Funknown"+
				 "&trust="+trust+
				 "&format="+format+
				 extra;
			}
		else {
			urlstr = "show.cgi"+urlize(f.path)+ext+
				 "?rand="+System.currentTimeMillis()+
				 "&trust="+trust+
				 "&format="+format+
				 extra;
			}

		// Do a test fetch
		String l[] = get_text(urlstr+"&test=1");
		if (l[0].length() > 0) {
			new ErrorWindow(text("eopen", l[0]));
			return;
			}

		// Open for real
		if (download) {
			getAppletContext().showDocument(
				new URL(getDocumentBase(), urlstr));
			}
		else {
			getAppletContext().showDocument(
				new URL(getDocumentBase(), urlstr), "show");
			}
		}
	catch(Exception e) { }
	}

	static String urlize(String s)
	{
	StringBuffer rv = new StringBuffer();
	for(int i=0; i<s.length(); i++) {
		char c = s.charAt(i);
		if (c < 16)
			rv.append("%0"+Integer.toString(c, 16));
		else if ((!Character.isLetterOrDigit(c) && c != '/' &&
		    c != '.' && c != '_' && c != '-') || c >= 128)
			rv.append("%"+Integer.toString(c, 16));
		else
			rv.append(c);
		}
	return rv.toString();
	}

	static String un_urlize(String s)
	{
	StringBuffer rv = new StringBuffer();
	for(int i=0; i<s.length(); i++) {
		char c = s.charAt(i);
		if (c == '%') {
			rv.append((char)Integer.parseInt(
				s.substring(i+1, i+3), 16));
			i += 2;
			}
		else
			rv.append(c);
		}
	return rv.toString();
	}

	// Called back by Javascript when a file or directory has been modified
	public void upload_notify(String path_str, String info)
	{
	int sl = path_str.lastIndexOf('/');
	String par_str = path_str.substring(0, sl),
	       file_str = path_str.substring(sl+1);
	RemoteFile par = find_directory(par_str, false);
	RemoteFile upfile = par.find(file_str);
	try {
		if (upfile == null) {
			// Need to add this file/directory
			upfile = new RemoteFile(this, info, par);
			par.add(upfile);
			}
		else if (upfile.type == RemoteFile.DIR) {
			// Is a directory .. refresh from server
			FileNode upnode = (FileNode)nodemap.get(upfile);
			if (upnode != null)
				upnode.refresh();
			}
		show_files(showing_files);
		}
	catch(Exception e) {
		// In some cases, any attempt to make an HTTP request to
		// refresh the directory may fail because Java apparently has
		// some security rules that limit what a function called from
		// JavaScript is allowed to do. All we can do is ignore the
		// exception :-(
		e.printStackTrace();
		}
	}

	// Called back by Javascript to show an upload-related error
	public void upload_error(String err)
	{
	new ErrorWindow(err);
	}

	public String text(String k, String p[])
	{
	String rv = (String)lang.get(k);
	if (rv == null) rv = "???";
	for(int i=0; i<p.length; i++) {
		int idx = rv.indexOf("$"+(i+1));
		if (idx != -1)
			rv = rv.substring(0, idx)+p[i]+rv.substring(idx+2);
		}
	return rv;
	}

	public String text(String k)
	{
	String p[] = { };
	return text(k, p);
	}

	public String text(String k, String p1)
	{
	String p[] = { p1 };
	return text(k, p);
	}

	public String text(String k, String p1, String p2)
	{
	String p[] = { p1, p2 };
	return text(k, p);
	}

	RemoteFile paste_file(RemoteFile src, RemoteFile dir,
			      String dest, RemoteFile already, boolean mode)
	{
	// Move or copy the actual file
	String[] rv = get_text((mode ? "move.cgi" : "copy.cgi")+
			       "?from="+urlize(src.path)+
			       "&to="+urlize(dest));
	if (rv[0].length() > 0) {
		new ErrorWindow(text(
			mode ? "paste_emfailed" : "paste_ecfailed", rv[0]));
		return null;
		}
	RemoteFile file = new RemoteFile(this, rv[1], dir);
	if (already == null) {
		// Add to the parent directory
		dir.add(file);
		}
	else {
		// Update the existing file
		already.type = file.type;
		already.user = file.user;
		already.group = file.group;
		already.size = file.size;
		already.perms = file.perms;
		already.modified = file.modified;
		file = already;
		}
	if (mode) {
		// Delete the old file
		src.directory.delete(src);
		}
	if (src.type == 0) {
		// Moving or copying a directory.. update the tree
		FileNode dest_par_node =
			(FileNode)nodemap.get(showing_files);
		dest_par_node.add(new FileNode(file));
		if (mode) {
			FileNode cut_par_node =
				(FileNode)nodemap.get(src.directory);
			FileNode cut_file_node =
				(FileNode)nodemap.get(src);
			if (cut_par_node != null &&
			    cut_file_node != null)
				cut_par_node.ch.removeElement(
							cut_file_node);
			}
		dirs.redraw();
		}
	show_files(showing_files);
	return file;
	}

	// Loads the list of filesystems from the server, and refreshes all
	// caches
	void get_filesystems()
	{
	String f[] = get_text("filesystems.cgi");
	got_filesystems = f[0].equals("1");
	acl_support = false;
	attr_support = false;
	ext_support = false;
	mounts.clear();
	fslist.removeAllElements();
	if (got_filesystems) {
		for(int i=1; i<f.length; i++) {
			FileSystem fs = new FileSystem(f[i]);
			fslist.addElement(fs);
			if (fs.acls) acl_support = true;
			if (fs.attrs) attr_support = true;
			if (fs.ext) ext_support = true;
			mounts.put(fs.mount, fs);
			}
		}
	}

	String join_array(String l[])
	{
	String rv = "";
	for(int i=0; i<l.length; i++)
		rv += l[i]+"\n";
	return rv;
	}

	static String replace_str(String str, String os, String ns)
	{
	String rv;
	int idx;
	int pos = 0;
	rv = str;
	while((idx = rv.indexOf(os, pos)) >= 0) {
		rv = rv.substring(0, idx)+
		      ns+rv.substring(idx+os.length());
		pos = idx+ns.length()+1;
		}
	return rv;
	}
}

// A node in the directory tree
class FileNode extends HierarchyNode
{
	FileManager parent;
	RemoteFile file;
	boolean known;

	FileNode(RemoteFile file)
	{
	this.file = file;
	parent = file.parent;
	setimage();
	ch = new Vector();
	text = file.name;
	parent.nodemap.put(file, this);
	}

	// Create the nodes for subdirectories
	void fill()
	{
	if (!known) {
		RemoteFile l[] = file.list();
		if (l == null) return;
		ch.removeAllElements();
		for(int i=0; i<l.length; i++)
			if (l[i].type == 0)
				ch.addElement(new FileNode(l[i]));
		parent.dirs.redraw();
		known = true;
		}
	}

	void add(FileNode n)
	{
	for(int i=0; i<=ch.size(); i++) {
		FileNode ni = i==ch.size() ? null : (FileNode)ch.elementAt(i);
		if (ni == null || ni.text.compareTo(n.text) > 0) {
			ch.insertElementAt(n, i);
			break;
			}
		}
	}

	void setimage()
	{
	im = parent.get_image(file.shared() && file.mounted() ? "smdir.gif" :
			      file.shared() && file.mountpoint() ? "sudir.gif" :
			      file.shared() ? "sdir.gif" :
			      file.mounted() ? "mdir.gif" :
			      file.mountpoint() ? "udir.gif" :
						  "dir.gif");
	}

	// Forces a re-load from the server
	void refresh()
	{
	known = false;
	file.list = null;
	fill();
	}
}

class RemoteFile
{
	static final int DIR = 0;
	static final int TEXT = 1;
	static final int IMAGE = 2;
	static final int BINARY = 3;
	static final int UNKNOWN = 4;
	static final int SYMLINK = 5;
	static final int DEVICE = 6;
	static final int PIPE = 7;
	static final String[] tmap = { "dir.gif", "text.gif", "image.gif",
				       "binary.gif", "unknown.gif",
				       "symlink.gif", "device.gif",
				       "pipe.gif" };

	FileManager parent;
	String path, name;
	int type;
	String user, group;
	long size;
	int perms;
	long modified;
	String linkto;
	RemoteFile list[];
	RemoteFile directory;

	// Parse a line of text to a file object
	RemoteFile(FileManager parent, String line, RemoteFile d)
	{
	this.parent = parent;
	StringTokenizer tok = new StringTokenizer(line, "\t");
	if (tok.countTokens() < 7) {
		String err = "Invalid file line : "+line;
		new ErrorWindow(err);
		throw new Error(err);
		}
	path = tok.nextToken();
	path = parent.replace_str(path, "\\t", "\t");
	path = parent.replace_str(path, "\\\\", "\\");
	type = Integer.parseInt(tok.nextToken());
	user = tok.nextToken();
	group = tok.nextToken();
	size = Long.parseLong(tok.nextToken());
	perms = Integer.parseInt(tok.nextToken());
	modified = Long.parseLong(tok.nextToken())*1000;
	if (type == 5) linkto = tok.nextToken();
	directory = d;
	if (path.equals("/")) name = "/";
	else name = path.substring(path.lastIndexOf('/')+1);
	}

	// Create a new, empty file object
	RemoteFile() { }

	// Returns a list of files in this directory
	RemoteFile[] list()
	{
	if (list == null) {
		String l[] = parent.get_text("list.cgi?dir="+
					     parent.urlize(path));
		if (l[0].length() > 0) {
			//list = new RemoteFile[0];
			// Error reading the remote directory!
			new ErrorWindow(parent.text("list_edir", path, l[0]));
			list = null;
			}
		else {
			list = new RemoteFile[l.length-3];
			for(int i=3; i<l.length; i++)
				list[i-3] = new RemoteFile(parent, l[i], this);
			}
		}
	return list;
	}

	RemoteFile find(String n)
	{
	RemoteFile l[] = list();
	if (l != null) {
		for(int i=0; i<l.length; i++)
			if (l[i].name.equals(n))
				return l[i];
		}
	return null;
	}

	void add(RemoteFile f)
	{
	RemoteFile nlist[] = new RemoteFile[list.length+1];
	int offset = 0;
	for(int i=0; i<list.length; i++) {
		if (list[i].name.compareTo(f.name) > 0 && offset == 0) {
			nlist[i] = f;
			offset++;
			}
		nlist[i+offset] = list[i];
		}
	if (offset == 0) nlist[list.length] = f;
	list = nlist;
	}

	void delete(RemoteFile f)
	{
	RemoteFile nlist[] = new RemoteFile[list.length-1];
	for(int i=0,j=0; i<list.length; i++)
		if (list[i] != f)
			nlist[j++] = list[i];
	list = nlist;
	}

	boolean shared()
	{
	return type == DIR &&
	       (parent.stab.get(path) != null ||
	        parent.ntab.get(path) != null);
	}

	boolean mountpoint()
	{
	return type == DIR && fs() != null;
	}

	boolean mounted()
	{
	FileSystem fs = fs();
	return type == DIR && fs != null && fs.mtab;
	}

	FileSystem fs()
	{
	return (FileSystem)parent.mounts.get(path);
	}

}

class EditorWindow extends FixedFrame implements CbButtonCallback
{
	TextField name;
	TextArea edit;
	CbButton save_b, saveclose_b, cancel_b, goto_b, find_b;
	Checkbox dosmode;
	RemoteFile file;
	FileManager filemgr;
	GotoWindow goto_window;
	FindReplaceWindow find_window;
	String charset;

	// Editing an existing file
	EditorWindow(RemoteFile f, FileManager p)
	{
	super(800, 600);
	file = f; filemgr = p;
	makeUI(false);
	setTitle(filemgr.text("edit_title", file.path));

	// Load the file
	try {
		URL u = new URL(filemgr.getDocumentBase(),
				"show.cgi"+filemgr.urlize(file.path)+
				"?rand="+System.currentTimeMillis()+
				"&trust="+filemgr.trust+"&edit=1"+
				filemgr.extra);
		URLConnection uc = u.openConnection();
		filemgr.set_cookie(uc);
		int len = uc.getContentLength();
		InputStream is = uc.getInputStream();
		charset = filemgr.get_charset(uc.getContentType());
		byte buf[];
		if (len >= 0) {
			// Length is known
			buf = new byte[uc.getContentLength()];
			int got = 0;
			while(got < buf.length)
				got += is.read(buf, got, buf.length-got);
			}
		else {
			// Length is unknown .. read till the end
			buf = new byte[0];
			while(true) {
			    byte data[] = new byte[16384];
			    int got;
			    try { got = is.read(data); }
			    catch(EOFException ex) { break; }
			    if (got <= 0) break;
			    byte nbuf[] = new byte[buf.length + got];
			    System.arraycopy(buf, 0, nbuf, 0, buf.length);
			    System.arraycopy(data, 0, nbuf, buf.length, got);
			    buf = nbuf;
			    }
			}
		String s = charset == null ? new String(buf, 0)
					   : new String(buf, charset);
		if (s.indexOf("\r\n") != -1) {
			dosmode.setState(true);
			s = FileManager.replace_str(s, "\r\n", "\n");
			}
		edit.setText(s);
		is.close();
		file.size = buf.length;
		}
	catch(Exception e) { e.printStackTrace(); }
	}

	// Creating a new file
	EditorWindow(String f, FileManager p)
	{
	super(800, 600);
	filemgr = p;
	makeUI(true);
	setTitle(filemgr.text("edit_title2"));
	name.setText(f.equals("/") ? f : f+"/");
	name.select(name.getText().length(), name.getText().length());
	}

	void makeUI(boolean add_name)
	{
	setLayout(new BorderLayout());
	if (add_name) {
		Panel np = new Panel();
		np.setLayout(new BorderLayout());
		np.add("West", new Label(filemgr.text("edit_filename")));
		np.add("Center", name = new TextField());
		name.setFont(filemgr.fixed);
		add("North", np);
		}
	add("Center", edit = new TextArea(20, 80));
	edit.setEditable(true);
	edit.setFont(filemgr.fixed);
	Panel bot = new Panel();
	bot.setLayout(new FlowLayout(FlowLayout.RIGHT));
	bot.add(dosmode = new Checkbox("Windows newlines"));
	bot.add(goto_b = new CbButton(filemgr.get_image("goto.gif"),
				      filemgr.text("edit_goto"),
				      CbButton.LEFT, this));
	bot.add(find_b = new CbButton(filemgr.get_image("find.gif"),
				      filemgr.text("edit_find"),
				      CbButton.LEFT, this));
	bot.add(new Label(" "));
	bot.add(save_b = new CbButton(filemgr.get_image("save.gif"),
				      filemgr.text("save"),
				      CbButton.LEFT, this));
	bot.add(saveclose_b = new CbButton(filemgr.get_image("save.gif"),
				      filemgr.text("edit_saveclose"),
				      CbButton.LEFT, this));
	bot.add(cancel_b = new CbButton(filemgr.get_image("cancel.gif"),
					filemgr.text("close"),
					CbButton.LEFT, this));
	add("South", bot);
	Util.recursiveBody(this);
	pack();
	show();
	}

	public void click(CbButton b)
	{
	if (b == save_b || b == saveclose_b) {
		RemoteFile par = null, already = null;
		String save_path;
		if (file == null) {
			// Locate the filemgr directory
			save_path = filemgr.trim_path(name.getText());
			int sl = save_path.lastIndexOf('/');
			par = filemgr.find_directory(
					save_path.substring(0, sl), false);
			if (par == null) return;
			already = par.find(save_path.substring(sl+1));
			if (already != null &&
			    (already.type == 0 || already.type == 5)) {
				new ErrorWindow(
					filemgr.text("edit_eover", save_path));
				return;
				}
			}
		else save_path = file.path;

		// Save the file back again
		String s = edit.getText(), line;
		s = FileManager.replace_str(s, "\r\n", "\n");
		try {
			if (dosmode.getState()) {
				// Convert to DOS newlines
				s = FileManager.replace_str(s, "\n", "\r\n");
				}
			else {
				// Remove any DOS newlines
				s = FileManager.replace_str(s, "\r\n", "\n");
				}
			URL u = new URL(filemgr.getDocumentBase(),
					"save.cgi"+filemgr.urlize(save_path)+
					"?rand="+System.currentTimeMillis()+
					"&trust="+filemgr.trust+
					"&length="+s.length()+
					filemgr.extra);
			URLConnection uc = u.openConnection();
			uc.setRequestProperty("Content-type", "text/plain");
			filemgr.set_cookie(uc);
			uc.setDoOutput(true);
			OutputStream os = uc.getOutputStream();
			byte buf[];
			if (charset == null) {
				// Assume ascii
				buf = new byte[s.length()];
				s.getBytes(0, buf.length, buf, 0);
				}
			else {
				// Convert back to original charset
				buf = s.getBytes(charset);
				}
			os.write(buf);
			os.close();
			BufferedReader is =
			    new BufferedReader(new InputStreamReader(
				uc.getInputStream()));
			String err = is.readLine();
			if (err.length() > 0) {
				new ErrorWindow(
					filemgr.text("edit_esave", err));
				is.close();
				return;
				}
			line = is.readLine();
			is.close();
			}
		catch(Exception e) { e.printStackTrace(); return; }

		if (file == null) {
			// Create and insert or replace the file object
			file = new RemoteFile(filemgr, line, par);
			if (already != null) {
				// A file with this name exists
				already.type = file.type;
				already.user = file.user;
				already.group = file.group;
				already.size = file.size;
				already.perms = file.perms;
				already.modified = file.modified;
				}
			else {
				// Add to the list
				par.add(file);
				}
			}
		else {
			file.size = s.length();
			file.modified = System.currentTimeMillis();
			}
		filemgr.show_files(filemgr.showing_files);
		if (b == saveclose_b)
			dispose();
		}
	else if (b == cancel_b) {
		// Just close
		dispose();
		}
	else if (b == goto_b) {
		// Open a dialog asking which line to go to
		if (goto_window != null)
			goto_window.toFront();
		else
			goto_window = new GotoWindow(this);
		}
	else if (b == find_b) {
		// Open the search (and replace) dialog
		if (find_window != null)
			find_window.toFront();
		else
			find_window = new FindReplaceWindow(this);
		}
	}

	public void dispose()
	{
	super.dispose();
	if (goto_window != null) goto_window.dispose();
	if (find_window != null) find_window.dispose();
	}
}

class GotoWindow extends FixedFrame implements CbButtonCallback
{
	EditorWindow editor;
	FileManager filemgr;
	TextField line;
	CbButton goto_b, cancel_b;

	GotoWindow(EditorWindow e)
	{
	editor = e;
	filemgr = e.filemgr;

	setLayout(new BorderLayout());
	add("West", new Label(filemgr.text("edit_gotoline")));
	add("Center", line = new TextField(10));
	line.setFont(filemgr.fixed);
	Panel bot = new Panel();
	bot.setLayout(new FlowLayout(FlowLayout.RIGHT));
	bot.add(goto_b = new CbButton(filemgr.get_image("goto.gif"),
				      filemgr.text("edit_goto"),
				      CbButton.LEFT, this));
	bot.add(cancel_b = new CbButton(filemgr.get_image("cancel.gif"),
				        filemgr.text("close"),
				        CbButton.LEFT, this));
	add("South", bot);
	Util.recursiveBody(this);
	pack();
	show();
	}

	public void click(CbButton b)
	{
	if (b == goto_b) {
		// Go to the chose line, if it exists
		int lnum;
		try { lnum = Integer.parseInt(line.getText()); }
		catch(Exception e) { return; }

		String txt = editor.edit.getText();
		int c, l = 0;
		for(c=0; c<txt.length(); c++) {
			if (txt.charAt(c) == '\n') {
				l++;
				if (l == lnum) {
					// Found the line!
					editor.edit.select(c, c);
					dispose();
					editor.edit.requestFocus();
					return;
					}
				}
			}
		}
	else if (b == cancel_b) {
		// Just close the window
		dispose();
		}
	}

	public void dispose()
	{
	super.dispose();
	editor.goto_window = null;
	}

	public boolean handleEvent(Event e)
	{
	if (e.target == line && e.id == Event.KEY_RELEASE && e.key == 10) {
		click(goto_b);
		return true;
		}
	return false;
	}
}

class FindReplaceWindow extends FixedFrame implements CbButtonCallback
{
	EditorWindow editor;
	FileManager filemgr;
	TextField find, replace;
	CbButton find_b, replace_b, all_b, cancel_b;

	FindReplaceWindow(EditorWindow e)
	{
	editor = e;
	filemgr = e.filemgr;
	setLayout(new BorderLayout());

	Panel left = new Panel();
	left.setLayout(new GridLayout(2, 1));
	left.add(new Label(filemgr.text("edit_searchfor")));
	left.add(new Label(filemgr.text("edit_replaceby")));
	add("West", left);

	Panel right = new Panel();
	right.setLayout(new GridLayout(2, 1));
	right.add(find = new TextField(40));
	find.setFont(filemgr.fixed);
	right.add(replace = new TextField(40));
	replace.setFont(filemgr.fixed);
	add("Center", right);

	Panel bot = new Panel();
	bot.setLayout(new FlowLayout(FlowLayout.RIGHT));
	bot.add(find_b = new CbButton(filemgr.get_image("find.gif"),
				      filemgr.text("edit_find"),
				      CbButton.LEFT, this));
	bot.add(replace_b = new CbButton(filemgr.get_image("replace.gif"),
				      filemgr.text("edit_replace"),
				      CbButton.LEFT, this));
	bot.add(all_b = new CbButton(filemgr.get_image("all.gif"),
				      filemgr.text("edit_all"),
				      CbButton.LEFT, this));
	bot.add(cancel_b = new CbButton(filemgr.get_image("cancel.gif"),
				        filemgr.text("close"),
				        CbButton.LEFT, this));
	add("South", bot);
	Util.recursiveBody(this);
	pack();
	show();
	}

	public void click(CbButton b)
	{
	String findtxt = find.getText();
	String edittxt = editor.edit.getText();
	if (findtxt.length() == 0)
		return;
	if (b == find_b) {
		// Find the next occurrence of the text, starting from
		// the cursor + 1, and select it
		int pos = edittxt.indexOf(findtxt,
					   editor.edit.getSelectionStart()+1);
		if (pos < 0) {
			// Not found .. but try wrap-around
			pos = edittxt.indexOf(findtxt, 0);
			}
		if (pos < 0)
			new ErrorWindow(filemgr.text("edit_notfound", findtxt));
		else {
			editor.edit.select(pos, pos+findtxt.length());
			editor.edit.requestFocus();
			}
		}
	else if (b == replace_b) {
		// If the word to search for is selected, replace it. Otherwise
		// just search for the next one
		int st = editor.edit.getSelectionStart(),
		    en = editor.edit.getSelectionEnd();
		if (st >= 0) {
			String sel = edittxt.substring(st, en);
			if (sel.equals(findtxt)) {
				// Replace the selected
				editor.edit.setText(edittxt.substring(0, st)+
						    replace.getText()+
						    edittxt.substring(en));
				editor.edit.select(st, st);
				return;
				}
			}
		click(find_b);
		}
	else if (b == all_b) {
		// Replace all occurrences of the text in the editor
		int pos = 0;
		int len = findtxt.length();
		int st = editor.edit.getSelectionStart(),
		    en = editor.edit.getSelectionEnd();
		while((pos = edittxt.indexOf(findtxt, pos)) != -1) {
			edittxt = edittxt.substring(0, pos)+
				  replace.getText()+
				  edittxt.substring(pos+len);
			pos += len;
			}
		editor.edit.setText(edittxt);
		editor.edit.select(st, en);	// put back old selection
		}
	else if (b == cancel_b) {
		// Just close the window
		dispose();
		}
	}

	public void dispose()
	{
	super.dispose();
	editor.find_window = null;
	}
}

class PropertiesWindow extends FixedFrame implements CbButtonCallback
{
	RemoteFile file;
	FileManager filemgr;
	CbButton save_b, cancel_b, size_b;

	TextField linkto;
	TextField user, group;
	Checkbox setuid, setgid;
	PermissionsPanel user_p, group_p, other_p;
	Checkbox sticky;
	Choice rec_mode;
	TextField octal;

	TextField bytes, files, dirs;

	PropertiesWindow(RemoteFile f, FileManager p)
	{
	file = f;
	filemgr = p;

	// Create UI
	setTitle(f.path);
	setLayout(new BorderLayout());
	Panel bot = new Panel();
	bot.setLayout(new FlowLayout(FlowLayout.RIGHT));
	if (file.type == 0) {
		bot.add(size_b = new CbButton(filemgr.get_image("refresh.gif"),
					      filemgr.text("info_getsize"),
					      CbButton.LEFT, this));
		}
	if (filemgr.can_perms || filemgr.can_users) {
		bot.add(save_b = new CbButton(filemgr.get_image("save.gif"),
					      filemgr.text("save"),
					      CbButton.LEFT, this));
		}
	bot.add(cancel_b = new CbButton(filemgr.get_image("cancel.gif"),
					filemgr.text("cancel"),
					CbButton.LEFT, this));
	add("South", bot);

	Panel mid = new Panel();
	mid.setLayout(new BorderLayout());
	TabbedPanel tab = null;
	add("Center", mid);

	// Create file details section
	Panel det = new LinedPanel(filemgr.text("info_file")),
	      dl = new Panel(), dr = new Panel();
	setup_leftright(det, dl, dr);
	add_item(filemgr.text("info_path"),
		new Label(file.path), dl, dr);
	add_item(filemgr.text("info_type"),
		new Label(filemgr.text("file_type"+file.type)), dl, dr);
	add_item(filemgr.text("info_size"),
		new Label(String.valueOf(file.size)),dl,dr);
	add_item(filemgr.text("info_mod"),
		new Label(String.valueOf(new Date(file.modified))), dl, dr);
	if (file.type == 5) {
		add_item(filemgr.text("info_link"),
			 linkto = new TextField(file.linkto, 30), dl, dr);
		linkto.setFont(filemgr.fixed);
		}
	mid = add_panel(mid, det);

	if (filemgr.can_perms) {
		// Create permissions section
		Panel per = new LinedPanel(filemgr.text("info_perms")),
		      pl = new Panel(), pr = new Panel();
		setup_leftright(per, pl, pr);
		add_item(filemgr.text("info_user"),
		    user_p = new PermissionsPanel(file, 64, filemgr), pl, pr);
		add_item(filemgr.text("info_group"),
		    group_p = new PermissionsPanel(file, 8, filemgr), pl, pr);
		add_item(filemgr.text("info_other"),
		    other_p = new PermissionsPanel(file, 1, filemgr), pl,pr);
		if (file.type == 0) {
			add_item(filemgr.text("info_sticky"),
			    sticky = new Checkbox(filemgr.text("info_sticky2")),
			    pl,pr);
			sticky.setState((file.perms&01000) != 0);
			}
		add_item(filemgr.text("info_octal"),
			 octal = new TextField(4), pl, pr);
		octal.setFont(filemgr.fixed);
		octal.setEditable(false);
		mid = add_panel(mid, per);
		}

	if (filemgr.can_users) {
		// Create ownership section
		Panel own = new LinedPanel(filemgr.text("info_own")),
		      ol = new Panel(), or = new Panel();
		setup_leftright(own, ol, or);
		add_item(filemgr.text("info_user"),
			 user = new TextField(file.user, 10), ol, or);
		user.setFont(filemgr.fixed);
		if (file.type != 0) {
			add_item(filemgr.text("info_setuid"),
			    setuid = new Checkbox(filemgr.text("info_setuid2")),
			    ol, or);
			setuid.setState((file.perms & 0x800) != 0);
			}
		add_item(filemgr.text("info_group"),
			 group = new TextField(file.group, 10), ol, or);
		group.setFont(filemgr.fixed);
		if (file.type == 0)
			add_item(filemgr.text("info_setgid"),
			  setgid = new Checkbox(filemgr.text("info_setgid2")),
			  ol, or);
		else
			add_item(filemgr.text("info_setgid"),
			  setgid = new Checkbox(filemgr.text("info_setgid3")),
			  ol, or);
		setgid.setState((file.perms & 0x400) != 0);
		mid = add_panel(mid, own);
		}

	if (file.type == 0) {
		// Create directory size section, initially empty
		Panel szp = new LinedPanel(filemgr.text("info_sizeheader")),
		      sl = new Panel(), sr = new Panel();
		setup_leftright(szp, sl, sr);
		add_item(filemgr.text("info_bytes"),
			 bytes = new TextField("", 10), sl, sr);
		bytes.setFont(filemgr.fixed);
		bytes.setEditable(false);
		add_item(filemgr.text("info_files"),
			 files = new TextField("", 10), sl, sr);
		files.setFont(filemgr.fixed);
		files.setEditable(false);
		add_item(filemgr.text("info_dirs"),
			 dirs = new TextField("", 10), sl, sr);
		dirs.setFont(filemgr.fixed);
		dirs.setEditable(false);
		mid = add_panel(mid, szp);
		}

	if (file.type == 0 && (filemgr.can_perms || filemgr.can_users)) {
		// Create recursion section
		Panel rec = new LinedPanel(filemgr.text("info_apply"));
		rec.setLayout(new BorderLayout());
		rec_mode = new Choice();
		for(int i=1; i<=5; i++)
			rec_mode.addItem(filemgr.text("info_apply"+i));
		rec.add("Center", rec_mode);
		mid = add_panel(mid, rec);
		}

	set_octal();
	Util.recursiveBody(this);
	pack();
	show();
	}

	Panel add_panel(Panel p, Component c)
	{
	p.add("North", c);
	Panel np = new Panel();
	np.setLayout(new BorderLayout());
	p.add("Center", np);
	return np;
	}

	public void click(CbButton b)
	{
	if (b == save_b) {
		// Update the file
		int perms = get_perms();
		String user_str = user != null ? user.getText() : null;
		String group_str = group != null ? group.getText() : null;
		int rec = 0;
		if (file.type == 0 && rec_mode != null)
			rec = rec_mode.getSelectedIndex();
		String rv[] = filemgr.get_text(
			"chmod.cgi?path="+filemgr.urlize(file.path)+
			(perms < 0 ? "" : "&perms="+perms)+
			(user_str == null ? "" :
				"&user="+filemgr.urlize(user_str))+
			(group_str == null ? "" :
				"&group="+filemgr.urlize(group_str))+
			"&rec="+rec+
			(linkto==null ? "" :
				"&linkto="+filemgr.urlize(linkto.getText())));
		if (rv[0].length() > 0) {
			// Something went wrong
			new ErrorWindow(filemgr.text("info_efailed",
					file.path, rv[0]));
			}
		else {
			// Update all changed file objects
			if (linkto != null)
				file.linkto = linkto.getText();
			else if (rec == 0) {
				// This file or directory only
				update_file(file, perms, false);
				}
			else if (rec == 1) {
				// Update files in this directory
				update_file(file, perms, false);
				recurse_files(file, perms, false, false, true);
				}
			else if (rec == 2) {
				// Update files and subdirs
                                update_file(file, perms, false);
				recurse_files(file, perms, true, true, true);
				}
			else if (rec == 3) {
				// Update files only in dir and subdirs
				recurse_files(file, perms, true, false, true);
				}
			else if (rec == 4) {
				// Update dir and subdirs but not files
				recurse_files(file, perms, true, true, false);
				}

			// Update directory list
			int os = filemgr.files.selected();
			filemgr.show_files(filemgr.showing_files);
			filemgr.files.select(os);
			dispose();
			}
		}
	else if (b == size_b) {
		// Get the size of the directory recursively
		String l[] = filemgr.get_text("size.cgi?dir="+
					      filemgr.urlize(file.path));
		if (l[0].length() > 0) {
			new ErrorWindow(filemgr.text("info_size", l[0]));
			}
		StringTokenizer tok = new StringTokenizer(l[1], " ");
		String bytes_str = tok.nextToken();
		files.setText(tok.nextToken());
		dirs.setText(tok.nextToken());
		bytes.setText(tok.nextToken()+" "+tok.nextToken());
		}
	else {
		// Just close
		dispose();
		}
	}

	void update_file(RemoteFile f, int perms, boolean perms_only)
	{
	f.user = user.getText();
	f.group = group.getText();
	if (perms_only)
		f.perms = (perms & 0777) | (f.perms & 037777777000);
	else
		f.perms = perms;
	}

	void recurse_files(RemoteFile f, int perms, boolean do_subs,
			   boolean do_dirs, boolean do_files)
	{
	if (f.list == null) return;
	for(int i=0; i<f.list.length; i++) {
		RemoteFile ff = f.list[i];
		if (ff.type == 5) continue;
		else if (ff.type == 0) {
			if (do_subs) {
				if (do_dirs) {
					update_file(ff, perms, false);
					}
				recurse_files(ff, perms, true, do_dirs, do_files);
				}
			}
		else {
			if (do_files) {
				update_file(ff, perms, true);
				}
			}
		}
	}

	void setup_leftright(Panel m, Panel l, Panel r)
	{
	m.setLayout(new BorderLayout());
	Panel p = new Panel();
	p.setLayout(new BorderLayout());
	p.add("West", l);
	p.add("Center", r);
	l.setLayout(new GridLayout(0, 1));
	r.setLayout(new GridLayout(0, 1));
	m.add("North", p);
	}

	void add_item(String t, Component c, Panel l, Panel r)
	{
	l.add(new Label(t));
	Panel p = new Panel();
	p.setLayout(new BorderLayout());
	p.add("West", c);
	r.add(p);
	}

	void set_octal()
	{
	if (octal != null) {
		String oct = Integer.toOctalString(get_perms());
		while(oct.length() < 4)
			oct = "0"+oct;
		octal.setText(oct);
		}
	}

	int get_perms()
	{
	if (user_p == null)
		return -1;		// Cannot edit
	int perms = 0;
	if (setuid == null)
		perms |= (file.perms & 0x800);
	else
		perms |= (setuid.getState() ? 0x800 : 0);
	perms |= (setgid.getState() ? 0x400 : 0);
	perms |= user_p.getPerms();
	perms |= group_p.getPerms();
	perms |= other_p.getPerms();
	if (sticky == null)
		perms |= (file.perms & 01000);
	else
		perms |= (sticky.getState() ? 01000 : 0);
	return perms;
	}

	public boolean handleEvent(Event e)
	{
	if (e.target instanceof Checkbox) {
		set_octal();
		return true;
		}
	return super.handleEvent(e);
	}
}

class PermissionsPanel extends Panel
{
	Checkbox read, write, exec;
	int base;

	PermissionsPanel(RemoteFile file, int base, FileManager filemgr)
	{
	int perms = file.perms;
	this.base = base;
	setLayout(new GridLayout(1, 3));
	add(read = new Checkbox(filemgr.text("info_read")));
	read.setState((perms&(base<<2)) != 0);
	add(write = new Checkbox(filemgr.text("info_write")));
	write.setState((perms&(base<<1)) != 0);
	add(exec = new Checkbox(
		filemgr.text(file.type == RemoteFile.DIR ? "info_list"
							 : "info_exec")));
	exec.setState((perms&base) != 0);
	}

	int getPerms()
	{
	int rv = 0;
	rv |= (read.getState() ? (base<<2) : 0);
	rv |= (write.getState() ? (base<<1) : 0);
	rv |= (exec.getState() ? base : 0);
	return rv;
	}
}

class DeleteWindow extends FixedFrame implements CbButtonCallback
{
	CbButton delete_b, cancel_b;
	FileManager filemgr;
	RemoteFile files[];

	DeleteWindow(FileManager p, RemoteFile ff[])
	{
	filemgr = p;
	files = ff;
	setTitle(filemgr.text(ff.length > 1 ? "delete_mtitle" :
			      ff[0].type == 0 ? "delete_dtitle" :
						"delete_ftitle"));

	setLayout(new BorderLayout());
	if (ff.length > 1) {
		add("North", new Label(filemgr.text("delete_mdesc")));
		Panel mp = new Panel();
		mp.setLayout(new GridLayout(ff.length, 1));
		for(int i=0; i<ff.length; i++)
			mp.add(new Label(ff[i].path));
		add("Center", mp);
		}
	else
		add("Center", new MultiLabel(filemgr.text(
			ff[0].type == 0 ? "delete_ddesc" : "delete_fdesc",
			ff[0].path), 35));
	Panel bot = new Panel();
	bot.setLayout(new FlowLayout(FlowLayout.CENTER));
	bot.add(delete_b = new CbButton(filemgr.get_image("save.gif"),
				        filemgr.text("delete"),
					CbButton.LEFT, this));
	bot.add(cancel_b = new CbButton(filemgr.get_image("cancel.gif"),
					filemgr.text("cancel"),
					CbButton.LEFT, this));
	add("South", bot);
	Util.recursiveBody(this);
	pack();
	show();
	}

	public void click(CbButton b)
	{
	if (b == delete_b) {
		// Delete the file or directory
		boolean need_redraw = false, need_reshow = false;
		for(int i=0; i<files.length; i++) {
			RemoteFile file = files[i];
			String rv[] = filemgr.get_text("delete.cgi?file="+
					       filemgr.urlize(file.path));
			if (rv[0].length() > 0) {
				new ErrorWindow(filemgr.text("delete_efailed",
						file.path, rv[0]));
				break;
				}
			else {
				// done the deed.. update data structures
				RemoteFile pf = file.directory;
				pf.delete(file);
				if (filemgr.showing_files == pf) {
					// Need to refresh the list as well..
					need_reshow = true;
					}

				FileNode node = (FileNode)filemgr.nodemap.get(
							file);
				FileNode pnode = (FileNode)filemgr.nodemap.get(
							pf);
				if (node != null) {
					// Take the directory out of the tree..
					pnode.ch.removeElement(node);
					need_redraw = true;
					}
				}
			}
		if (need_reshow) filemgr.show_files(filemgr.showing_files);
		if (need_redraw) filemgr.dirs.redraw();
		dispose();
		}
	else if (b == cancel_b)
		dispose();
	}
}

class MkdirWindow extends FixedFrame implements CbButtonCallback
{
	FileManager filemgr;
	TextField dir;
	CbButton create_b, cancel_b;

	MkdirWindow(String d, FileManager p)
	{
	filemgr = p;
	setTitle(filemgr.text("mkdir_title"));
	setLayout(new BorderLayout());
	add("West", new Label(filemgr.text("mkdir_dir")));
	add("Center", dir = new TextField(d.equals("/") ? "/" : d+"/", 40));
	dir.setFont(filemgr.fixed);
	dir.select(dir.getText().length(), dir.getText().length());
	Panel bot = new Panel();
	bot.setLayout(new FlowLayout(FlowLayout.CENTER));
	bot.add(create_b = new CbButton(filemgr.get_image("save.gif"),
				        filemgr.text("create"),
					CbButton.LEFT, this));
	bot.add(cancel_b = new CbButton(filemgr.get_image("cancel.gif"),
					filemgr.text("cancel"),
					CbButton.LEFT, this));
	add("South", bot);
	Util.recursiveBody(this);
	pack();
	show();
	}

	public void click(CbButton b)
	{
	if (b == create_b) {
		// Find the filemgr directory
		String path = dir.getText();
		path = filemgr.trim_path(path);
		int sl = path.lastIndexOf('/');
		RemoteFile par = filemgr.find_directory(
					path.substring(0, sl), false);
		if (par.find(path.substring(sl+1)) != null) {
			new ErrorWindow(filemgr.text("mkdir_eexists", path));
			return;
			}
		String rv[] = filemgr.get_text("mkdir.cgi?dir="+
					       filemgr.urlize(path));
		if (rv[0].length() > 0) {
			new ErrorWindow(filemgr.text("mkdir_efailed", rv[0]));
			return;
			}
		RemoteFile file = new RemoteFile(filemgr, rv[1], par);
		par.add(file);
		FileNode parnode = (FileNode)filemgr.nodemap.get(par);
		if (parnode != null) {
			// Update the tree
			parnode.add(new FileNode(file));
			filemgr.dirs.redraw();
			}
		filemgr.show_files(filemgr.showing_files);
		dispose();
		}
	else dispose();
	}
}

class LinkWindow extends FixedFrame implements CbButtonCallback
{
	FileManager filemgr;
	TextField from, to;
	CbButton create_b, cancel_b;

	LinkWindow(String d, FileManager p)
	{
	filemgr = p;
	setLayout(new BorderLayout());
	setTitle(filemgr.text("link_title"));
	Panel l = new Panel(), r = new Panel();
	l.setLayout(new GridLayout(0, 1));
	l.add(new Label(filemgr.text("link_from")));
	l.add(new Label(filemgr.text("link_to")));
	r.setLayout(new GridLayout(0, 1));
	r.add(from = new TextField(d.equals("/") ? "/" : d+"/", 40));
	from.setFont(filemgr.fixed);
	from.select(from.getText().length(), from.getText().length());
	r.add(to = new TextField());
	to.setFont(filemgr.fixed);
	add("West", l); add("Center", r);
	Panel bot = new Panel();
	bot.setLayout(new FlowLayout(FlowLayout.CENTER));
	bot.add(create_b = new CbButton(filemgr.get_image("save.gif"),
				        filemgr.text("create"),
					CbButton.LEFT, this));
	bot.add(cancel_b = new CbButton(filemgr.get_image("cancel.gif"),
					filemgr.text("cancel"),
					CbButton.LEFT, this));
	add("South", bot);
	Util.recursiveBody(this);
	pack();
	show();
	}

	public void click(CbButton b)
	{
	if (b == create_b) {
		// Check inputs
		String from_str = from.getText().trim();
		if (!from_str.startsWith("/")) {
			new ErrorWindow(filemgr.text("link_efrom", from_str));
			return;
			}
		int sl = from_str.lastIndexOf('/');
		String par_str = from_str.substring(0, sl),
		       file_str = from_str.substring(sl+1);
		RemoteFile par = filemgr.find_directory(par_str, false);
		if (par == null) return;
		if (par.find(file_str) != null) {
			new ErrorWindow(filemgr.text("link_eexists", from_str));
			return;
			}

		// Create the actual link
		String rv[] = filemgr.get_text("makelink.cgi?from="+
					       filemgr.urlize(from_str)+"&to="+
					       filemgr.urlize(to.getText()));
		if (rv[0].length() > 0) {
			new ErrorWindow(filemgr.text("link_efailed", rv[0]));
			return;
			}
		RemoteFile file = new RemoteFile(filemgr, rv[1], par);
		par.add(file);
		filemgr.show_files(filemgr.showing_files);
		dispose();
		}
	else if (b == cancel_b)
		dispose();
	}
}

class RenameWindow extends FixedFrame implements CbButtonCallback
{
	FileManager filemgr;
	RemoteFile file;
	TextField oldname, newname;
	CbButton rename_b, cancel_b;

	RenameWindow(FileManager p, RemoteFile f)
	{
	filemgr = p; file = f;
	setLayout(new BorderLayout());
	setTitle(filemgr.text("rename_title", file.path));
	Panel l = new Panel(), r = new Panel();
	l.setLayout(new GridLayout(0, 1));
	l.add(new Label(filemgr.text("rename_old")));
	l.add(new Label(filemgr.text("rename_new")));
	r.setLayout(new GridLayout(0, 1));
	r.add(oldname = new TextField(file.name, 20));
	oldname.setEditable(false);
	oldname.setFont(filemgr.fixed);
	r.add(newname = new TextField(file.name, 20));
	newname.select(file.name.length(), file.name.length());
	newname.setFont(filemgr.fixed);
	add("West", l); add("Center", r);

	Panel bot = new Panel();
	bot.setLayout(new FlowLayout(FlowLayout.CENTER));
	bot.add(rename_b = new CbButton(filemgr.get_image("save.gif"),
				        filemgr.text("rename_ok"),
					CbButton.LEFT, this));
	bot.add(cancel_b = new CbButton(filemgr.get_image("cancel.gif"),
					filemgr.text("cancel"),
					CbButton.LEFT, this));
	add("South", bot);
	pack();
	show();
	Util.recursiveBody(this);
	}

	public void click(CbButton b)
	{
	if (b == rename_b) {
		// Work out destination file and directory
		String newstr = newname.getText().trim();
		if (newstr.length() == 0) return;
		RemoteFile destdir;
		String newpath;
		if (newstr.indexOf('/') >= 0) {
			// Different dir
			if (newstr.startsWith("/")) {
				// Some absolute path
				newpath = newstr;
				}
			else {
				// Relative to this dir
				newpath = file.directory.path+"/"+newstr;
				}
			int sl = newpath.lastIndexOf('/');
			String newdir = sl == 0 ? "/" : newpath.substring(0,sl);
			destdir = filemgr.find_directory(newdir, false);
			}
		else {
			// Same dir
			destdir = file.directory;
			int sl = file.path.lastIndexOf('/');
			newpath = file.path.substring(0, sl)+"/"+newstr;
			}

		// Work out filename only
		int sl = newpath.lastIndexOf('/');
		newstr = newpath.substring(sl+1);

		// Check for an existing file
		RemoteFile already = destdir.find(newstr);
		if (already != null) {
			new ErrorWindow(filemgr.text("rename_eexists", newstr));
			return;
			}

		// Rename the real file
		String rv[] = filemgr.get_text(
				"rename.cgi?old="+filemgr.urlize(file.path)+
				"&new="+filemgr.urlize(newpath));
		if (rv[0].length() > 0) {
			new ErrorWindow(filemgr.text("rename_efailed", rv[0]));
			return;
			}

		// Update data structure
		file.name = newstr;
		file.path = newpath;
		file.directory.delete(file);
		destdir.list();
		destdir.add(file);
		file.directory = destdir;
		file.list = null;
		FileNode parnode = (FileNode)filemgr.nodemap.get(file.directory);
		FileNode filenode = (FileNode)filemgr.nodemap.get(file);
		if (parnode != null && filenode != null) {
			// Need to refresh tree
			filenode.text = file.name;
			parnode.ch.removeElement(filenode);
			parnode.add(filenode);
			dispose();
			filemgr.dirs.redraw();
			}

		filemgr.show_files(filemgr.showing_files);
		dispose();
		}
	else if (b == cancel_b)
		dispose();
	}
}

class OverwriteWindow extends FixedFrame implements CbButtonCallback
{
	FileManager filemgr;
	RemoteFile src, already;
	TextField newname;
	CbButton ok, cancel;
	int idx;
	boolean mode;

	OverwriteWindow(FileManager p, RemoteFile a, RemoteFile s, int i)
	{
	filemgr = p; src = s; already = a; idx = i;
	mode = filemgr.cut_mode;
	setLayout(new BorderLayout());
	setTitle(filemgr.text("over_title"));
	add("North",
	    new MultiLabel(filemgr.text("over_msg", already.path), 30, 0));
	add("West", new Label(filemgr.text("over_new")));
	add("East", newname = new TextField(a.name, 30));
	newname.setFont(filemgr.fixed);

	Panel bot = new Panel();
	bot.setLayout(new FlowLayout(FlowLayout.RIGHT));
	bot.add(ok = new CbButton(filemgr.get_image("save.gif"),
				  filemgr.text("over_ok"),
				  CbButton.LEFT, this));
	bot.add(cancel = new CbButton(filemgr.get_image("cancel.gif"),
				  filemgr.text("cancel"),
				  CbButton.LEFT, this));
	add("South", bot);
	Util.recursiveBody(this);
	pack();
	show();
	}

	public void click(CbButton b)
	{
	if (b == cancel)
		dispose();
	else if (b == ok && newname.getText().length() > 0) {
		// paste the file, but with a new name
		RemoteFile ap = already.directory;
		RemoteFile newalready = ap.find(newname.getText());
		if (newalready == src) {
			new ErrorWindow(filemgr.text("paste_eself"));
			return;
			}
		if (newalready != null && (newalready.type == 0 ||
					   newalready.type == 5)) {
			new ErrorWindow(
				filemgr.text("paste_eover", newalready.path));
			return;
			}
		String dpath = (ap.path.equals("/") ? "/" :
				ap.path+"/")+newname.getText();
		RemoteFile nf = filemgr.paste_file(src, already.directory,
						   dpath, newalready, mode);
		if (filemgr.cut_mode && nf != null) {
			// Paste from the destination path from now on
			filemgr.cut_buffer[idx] = nf;
			}
		dispose();
		}
	}
}

class SambaShare
{
	String path;
	boolean available;
	boolean writable;
	int guest;
	String comment;

	SambaShare(String l)
	{
	StringSplitter tok = new StringSplitter(l, ':');
	path = tok.nextToken();
	available = tok.nextToken().equals("1");
	writable = tok.nextToken().equals("1");
	guest = Integer.parseInt(tok.nextToken());
	comment = tok.nextToken();
	}

	SambaShare(String p, boolean a, boolean w, int g, String c)
	{
	path = p;
	available = a;
	writable = w;
	guest = g;
	comment = c;
	}

	String params()
	{
	return "path="+FileManager.urlize(path)+
	       "&available="+(available ? 1 : 0)+
	       "&writable="+(writable ? 1 : 0)+
	       "&guest="+guest+
	       "&comment="+FileManager.urlize(comment);
	}
}

class DFSAdminExport
{
	String path;
	String desc;
	String ro, rw, root;

	DFSAdminExport(String l)
	{
	StringSplitter tok = new StringSplitter(l, ':');
	path = tok.nextToken();
	ro = tok.nextToken();
	rw = tok.nextToken();
	root = tok.nextToken();
	desc = tok.nextToken();
	}

	DFSAdminExport(String p, String d, String ro, String rw, String root)
	{
	path = p;
	desc = d;
	this.ro = ro;
	this.rw = rw;
	this.root = root;
	}

	static String[] split(String s)
	{
	StringTokenizer stok = new StringTokenizer(s, " ");
	String rv[] = new String[stok.countTokens()];
	for(int i=0; i<rv.length; i++)
		rv[i] = stok.nextToken();
	return rv;
	}

	String params()
	{
	return "path="+FileManager.urlize(path)+
	       "&ro="+FileManager.urlize(ro)+
	       "&rw="+FileManager.urlize(rw)+
	       "&root="+FileManager.urlize(root)+
	       "&desc="+FileManager.urlize(desc);
	}
}

class LinuxExport
{
	String path;
	String host[];
	boolean ro[];
	int squash[];

	LinuxExport(String l)
	{
	StringSplitter tok = new StringSplitter(l, ':');
	path = tok.nextToken();
	int c = tok.countTokens() / 3;
	host = new String[c];
	ro = new boolean[c];
	squash = new int[c];
	for(int i=0; tok.hasMoreTokens(); i++) {
		host[i] = tok.nextToken();
		ro[i] = tok.nextToken().equals("1");
		squash[i] = Integer.parseInt(tok.nextToken());
		}
	}

	LinuxExport(String p, String h[], String r[], String s[])
	{
	path = p;
	}

	String params()
	{
	String rv = "path="+FileManager.urlize(path)+
		    "&count="+host.length;
	for(int i=0; i<host.length; i++) {
		rv += "&host"+i+"="+FileManager.urlize(host[i]);
		rv += "&ro"+i+"="+(ro[i] ? 1 : 0);
		rv += "&squash"+i+"="+squash[i];
		}
	return rv;
	}
}

class SharingWindow extends FixedFrame implements CbButtonCallback
{
	CbButton save_b, cancel_b;
	RemoteFile file;
	FileManager filemgr;
	SambaShare sshare;
	DFSAdminExport dexport;
	LinuxExport lexport;
	Checkbox samba_on, samba_off;
	Checkbox writable_on, writable_off;
	Checkbox available_on, available_off;
	Checkbox guest_on, guest_off, guest_only;
	TextField comment;

	TextField desc;
	Checkbox nfs_on, nfs_off;
	TextField rwhosts, rohosts, roothosts;
	Checkbox rw[] = new Checkbox[3], ro[] = new Checkbox[3],
		 root[] = new Checkbox[3];

	TextField host[];
	Choice lro[], squash[];

	SharingWindow(RemoteFile f, FileManager p)
	{
	file = f; filemgr = p;
	setTitle(filemgr.text("share_title", file.path));
	sshare = (SambaShare)filemgr.stab.get(file.path);
	Object nshare = filemgr.ntab.get(file.path);
	if (filemgr.nfsmode == 1)
		lexport = (LinuxExport)nshare;
	else if (filemgr.nfsmode == 2)
		dexport = (DFSAdminExport)nshare;

	// setup UI
	setLayout(new BorderLayout());
	Panel samba = new Panel(), sl = new Panel(), sr = new Panel();
	samba.setLayout(new BorderLayout());
	Panel st = new Panel();
	st.setLayout(new GridLayout(2, 1));
	CheckboxGroup sg = new CheckboxGroup();
	st.add(samba_off = new Checkbox(filemgr.text("share_soff"), sg, 
				       sshare == null));
	st.add(samba_on = new Checkbox(filemgr.text("share_son"), sg,
					sshare != null));
	samba.add("North", st);

	Panel stop = new LinedPanel(filemgr.text("share_sheader"));
	setup_leftright(stop, sl, sr);

	comment = new TextField(sshare == null ? "" : sshare.comment, 25);
	comment.setFont(filemgr.fixed);
	add_item(filemgr.text("share_comment"), comment, sl, sr);

	Panel ap = new Panel();
	ap.setLayout(new GridLayout(1, 0));
	CheckboxGroup ag = new CheckboxGroup();
	ap.add(available_on = new Checkbox(filemgr.text("yes"), ag,
					  sshare == null || sshare.available));
	ap.add(available_off = new Checkbox(filemgr.text("no"), ag,
					  sshare != null && !sshare.available));
	add_item(filemgr.text("share_available"), ap, sl, sr);

	Panel wp = new Panel();
	wp.setLayout(new GridLayout(1, 0));
	CheckboxGroup wg = new CheckboxGroup();
	wp.add(writable_on = new Checkbox(filemgr.text("yes"), wg,
					  sshare == null || sshare.writable));
	wp.add(writable_off = new Checkbox(filemgr.text("no"), wg,
					   sshare != null && !sshare.writable));
	add_item(filemgr.text("share_writable"), wp, sl, sr);

	Panel gp = new Panel();
	gp.setLayout(new GridLayout(1, 0));
	CheckboxGroup gg = new CheckboxGroup();
	gp.add(guest_only = new Checkbox(filemgr.text("share_only"), gg,
				sshare != null && sshare.guest == 2));
	gp.add(guest_on = new Checkbox(filemgr.text("yes"), gg,
				sshare == null || sshare.guest == 1));
	gp.add(guest_off = new Checkbox(filemgr.text("no"), gg,
			 	sshare != null && sshare.guest == 0));
	add_item(filemgr.text("share_guest"), gp, sl, sr);

	samba.add("Center", stop);

	// Setup NFS UI
	Panel nfs = new Panel(), nl = new Panel(), nr = new Panel();
	nfs.setLayout(new BorderLayout());
	Panel nt = new Panel();
	nt.setLayout(new GridLayout(2, 1));
	CheckboxGroup ng = new CheckboxGroup();
	nt.add(nfs_off = new Checkbox(filemgr.text("share_noff"), ng, 
				      nshare == null));
	nt.add(nfs_on = new Checkbox(filemgr.text("share_non"), ng,
				     nshare != null));
	nfs.add("North", nt);

	Panel ntop = new LinedPanel(filemgr.text("share_nheader"));
	setup_leftright(ntop, nl, nr);
	if (filemgr.nfsmode == 1) {
		// Linux export mode
		nl.setLayout(new GridLayout(0, 1, 2, 2));
		nr.setLayout(new GridLayout(0, 1, 2, 2));
		nl.add(new Label(filemgr.text("share_host")));
		nr.add(new Label(filemgr.text("share_opts")));
		int c = lexport==null ? 0 : lexport.host.length;
		host = new TextField[c+1];
		lro = new Choice[c+1];
		squash = new Choice[c+1];
		for(int i=0; i<c; i++) {
			host[i] = new TextField(lexport.host[i], 20);
			host[i].setFont(filemgr.fixed);
			lro[i] = robox(lexport.ro[i]);
			squash[i] = squashbox(lexport.squash[i]);
			nl.add(host[i]);
			nr.add(opts_panel(lro[i], squash[i]));
			}
		host[c] = new TextField("", 20);
		host[c].setFont(filemgr.fixed);
		lro[c] = robox(false);
		squash[c] = squashbox(1);
		nl.add(host[c]);
		nr.add(opts_panel(lro[c], squash[c]));
		}
	else if (filemgr.nfsmode == 2) {
		// Solaris share mode
		desc = new TextField(dexport == null ? "" : dexport.desc, 25);
		desc.setFont(filemgr.fixed);
		add_item(filemgr.text("share_desc"), desc, nl, nr);

		rohosts = add_hosts(filemgr.text("share_ro"),
				    dexport == null ? "-" : dexport.ro,
				    ro, nl, nr);
		rwhosts = add_hosts(filemgr.text("share_rw"),
				    dexport == null ? "-" : dexport.rw,
				    rw, nl, nr);
		roothosts = add_hosts(filemgr.text("share_root"),
				    dexport == null ? "-" : dexport.root,
				    root, nl, nr);
		root[1].getParent().remove(root[1]);
		}
	else if (filemgr.nfsmode == 3) {
		}
	nfs.add("Center", ntop);

	// Add the appropriate tabs
	if (filemgr.sambamode && filemgr.nfsmode != 0) {
		TabbedPanel tab = new TabbedPanel();
		tab.addItem(filemgr.text("share_samba"), samba);
		tab.addItem(filemgr.text("share_nfs"), nfs);
		add("Center", tab);
		}
	else if (filemgr.sambamode)
		add("Center", samba);
	else if (filemgr.nfsmode != 0)
		add("Center", nfs);

	// Create save and cancel buttons
	Panel bot = new Panel();
	bot.setLayout(new FlowLayout(FlowLayout.RIGHT));
	bot.add(save_b = new CbButton(filemgr.get_image("save.gif"),
				      filemgr.text("save"),
				      CbButton.LEFT, this));
	bot.add(cancel_b = new CbButton(filemgr.get_image("cancel.gif"),
					filemgr.text("cancel"),
					CbButton.LEFT, this));
	add("South", bot);
	Util.recursiveBody(this);
	pack();
	show();
	}

	public void click(CbButton b)
	{
	if (b == save_b) {
		// Update samba settings on server
		if (sshare != null && samba_on.getState()) {
			// Updating share
			sshare.available = available_on.getState();
			sshare.writable = writable_on.getState();
			sshare.guest = guest_only.getState() ? 2 :
				       guest_on.getState() ? 1 : 0;
			sshare.comment = comment.getText();
			String rv[] = filemgr.get_text(
				"save_share.cgi?"+sshare.params());
			}
		else if (sshare != null) {
			// Deleting share
			String rv[] = filemgr.get_text(
				"save_share.cgi?delete=1&"+sshare.params());
			filemgr.stab.remove(sshare.path);
			}
		else if (samba_on.getState()) {
			// Creating share
			sshare = new SambaShare(file.path,
						available_on.getState(),
						writable_on.getState(),
						guest_only.getState() ? 2 :
						guest_on.getState() ? 1 : 0,
						comment.getText());
			filemgr.stab.put(sshare.path, sshare);
			String rv[] = filemgr.get_text(
				"save_share.cgi?new=1&"+sshare.params());
			}

		// Update NFS settings on server
		if (filemgr.nfsmode == 1) {
			if (lexport != null && nfs_on.getState()) {
				// Updating export
				export_options(lexport);
				String rv[] = filemgr.get_text(
					"save_export.cgi?"+lexport.params());
				}
			else if (lexport != null) {
				// Deleting export
				String rv[] = filemgr.get_text(
				  "save_export.cgi?delete=1&"+lexport.params());
				filemgr.ntab.remove(lexport.path);
				}
			else if (nfs_on.getState()) {
				// Creating export
				lexport = new LinuxExport(file.path, null,
							  null, null);
				export_options(lexport);
				String rv[] = filemgr.get_text(
				  "save_export.cgi?new=1&"+lexport.params());
				filemgr.ntab.put(lexport.path, lexport);
				}
			}
		else if (filemgr.nfsmode == 2) {
			if (dexport != null && nfs_on.getState()) {
				// Updating share
				dexport.desc = desc.getText();
				dexport.ro = ro[0].getState() ? "-" :
					     ro[1].getState() ? "" :
					     rohosts.getText();
				dexport.rw = rw[0].getState() ? "-" :
					     rw[1].getState() ? "" :
					     rwhosts.getText();
				dexport.root = root[0].getState() ? "-" :
					       roothosts.getText();
				String rv[] = filemgr.get_text(
					"save_export.cgi?"+dexport.params());
				}
			else if (dexport != null) {
				// Deleting share
				String rv[] = filemgr.get_text(
				  "save_export.cgi?delete=1&"+dexport.params());
				filemgr.ntab.remove(dexport.path);
				}
			else if (nfs_on.getState()) {
				// Creating new share
				dexport = new DFSAdminExport(file.path,
					desc.getText(),
					ro[0].getState() ? "-" :
					ro[1].getState() ? "" :
					rohosts.getText(),
					rw[0].getState() ? "-" :
					rw[1].getState() ? "" :
					rwhosts.getText(),
					root[0].getState() ? "-" :
					roothosts.getText());
				String rv[] = filemgr.get_text(
				    "save_export.cgi?new=1&"+dexport.params());
				filemgr.ntab.put(dexport.path, dexport);
				}
			}
		else if (filemgr.nfsmode == 3) {
			}

		filemgr.show_files(filemgr.showing_files);
		dispose();
		}
	else if (b == cancel_b)
		dispose();
	}

	void setup_leftright(Panel m, Panel l, Panel r)
	{
	m.setLayout(new BorderLayout());
	Panel p = new Panel();
	p.setLayout(new BorderLayout());
	p.add("West", l);
	p.add("Center", r);
	l.setLayout(new GridLayout(0, 1));
	r.setLayout(new GridLayout(0, 1));
	m.add("North", p);
	}

	void add_item(String t, Component c, Panel l, Panel r)
	{
	l.add(new Label(t));
	Panel p = new Panel();
	p.setLayout(new BorderLayout());
	p.add("West", c);
	r.add(p);
	}

	TextField add_hosts(String name, String v, Checkbox cb[],
			    Panel l, Panel r)
	{
	Panel p = new Panel();
	p.setLayout(new GridLayout(1, 3));
	CheckboxGroup g = new CheckboxGroup();
	p.add(cb[0] = new Checkbox(filemgr.text("share_none"), g,
				   v.equals("-")));
	p.add(cb[1] = new Checkbox(filemgr.text("share_all"), g,
				   v.length() == 0));
	p.add(cb[2] = new Checkbox(filemgr.text("share_listed"), g,
				   v.length() > 1));
	add_item(name, p, l, r);
	TextField t = new TextField(v.equals("-") ? "" : v, 25);
	t.setFont(filemgr.fixed);
	add_item("", t, l, r);
	return t;
	}

	Choice squashbox(int s)
	{
	Choice rv = new Choice();
	rv.addItem(filemgr.text("share_s0"));
	rv.addItem(filemgr.text("share_s1"));
	rv.addItem(filemgr.text("share_s2"));
	rv.select(s);
	return rv;
	}

	Choice robox(boolean r)
	{
	Choice rv = new Choice();
	rv.addItem(filemgr.text("share_lrw"));
	rv.addItem(filemgr.text("share_lro"));
	rv.select(r ? 1 : 0);
	return rv;
	}

	Panel opts_panel(Component ro, Component squash)
	{
	Panel p = new Panel();
	p.setLayout(new BorderLayout());
	p.add("West", ro);
	p.add("East", squash);
	return p;
	}

	void export_options(LinuxExport e)
	{
	int c = 0;
	for(int i=0; i<host.length; i++)
		if (host[i].getText().length() > 0)
			c++;
	e.host = new String[c];
	e.ro = new boolean[c];
	e.squash = new int[c];
	for(int i=0,j=0; i<host.length; i++) {
		if (host[i].getText().trim().length() > 0) {
			e.host[j] = host[i].getText();
			e.ro[j] = lro[i].getSelectedIndex() == 1;
			e.squash[j] = squash[i].getSelectedIndex();
			j++;
			}
		}
	}

}

class SearchWindow extends FixedFrame
	implements CbButtonCallback,MultiColumnCallback
{
	TabbedPanel tab;
	MultiColumn list;
	CbButton search_b, cancel_b, down_b;
	FileManager filemgr;
	TextField dir, match, user, group;
	Checkbox uany, usel, gany, gsel;
	Choice type;
	Checkbox sany, smore, sless;
	TextField more, less;
	Checkbox xon, xoff;
	String types[] = { "", "f", "d", "l", "p" };
	TextField cont;
	RemoteFile results[];

	SearchWindow(String d, FileManager p)
	{
	filemgr = p;
	setTitle(filemgr.text("search_title"));

	// setup UI
	setLayout(new BorderLayout());
	tab = new TabbedPanel();
	Panel search = new Panel();
	search.setLayout(new BorderLayout());
	tab.addItem(filemgr.text("search_crit"), search);
	Panel l = new Panel(), r = new Panel();
	l.setLayout(new GridLayout(0, 1));
	r.setLayout(new GridLayout(0, 1));

	String cols[] = { "", filemgr.text("right_name"),
			  filemgr.text("right_size") };
	float widths[] = { .07f, .78f, .15f };
	list = new MultiColumn(cols, this);
	list.setWidths(widths);
	list.setDrawLines(false);
	list.setFont(filemgr.fixed);
	tab.addItem(filemgr.text("search_list"), list);

	add_item(filemgr.text("search_dir"), dir = new TextField(d, 30), l, r);
	dir.setFont(filemgr.fixed);

	// Filename
	add_item(filemgr.text("search_match"), match = new TextField(20), l, r);
	match.setFont(filemgr.fixed);

	if (filemgr.search_contents) {
		// File contents
		add_item(filemgr.text("search_cont"),
			 cont = new TextField(30), l, r);
		cont.setFont(filemgr.fixed);
		}

	// User or group owners
	if (filemgr.can_users) {
		Panel up = new Panel();
		up.setLayout(new FlowLayout(FlowLayout.LEFT, 1, 1));
		CheckboxGroup ug = new CheckboxGroup();
		up.add(uany = new Checkbox(filemgr.text("search_any"), ug, true));
		up.add(usel = new Checkbox("", ug, false));
		up.add(user = new TextField(10));
		user.setFont(filemgr.fixed);
		add_item(filemgr.text("search_user"), up, l, r);

		Panel gp = new Panel();
		gp.setLayout(new FlowLayout(FlowLayout.LEFT, 1, 1));
		CheckboxGroup gg = new CheckboxGroup();
		gp.add(gany = new Checkbox(filemgr.text("search_any"), gg, true));
		gp.add(gsel = new Checkbox("", gg, false));
		gp.add(group = new TextField(10));
		group.setFont(filemgr.fixed);
		add_item(filemgr.text("search_group"), gp, l, r);
		}

	// File type
	if (!filemgr.follow_links) {
		type = new Choice();
		for(int i=0; i<types.length; i++)
			type.addItem(filemgr.text("search_types_"+types[i]));
		add_item(filemgr.text("search_type"), type, l, r);
		}

	// File size
	CheckboxGroup sg = new CheckboxGroup();
	add_item(filemgr.text("search_size"),
		 sany = new Checkbox(filemgr.text("search_any"), sg, true),
		 l, r);
	Panel mp = new Panel();
	mp.setLayout(new FlowLayout(FlowLayout.LEFT, 1, 1));
	mp.add(smore = new Checkbox(filemgr.text("search_more"), sg, false));
	mp.add(more = new TextField(10));
	more.setFont(filemgr.fixed);
	add_item("", mp, l, r);
	Panel lp = new Panel();
	lp.setLayout(new FlowLayout(FlowLayout.LEFT, 1, 1));
	lp.add(sless = new Checkbox(filemgr.text("search_less"), sg, false));
	lp.add(less = new TextField(10));
	less.setFont(filemgr.fixed);
	add_item("", lp, l, r);

	if (filemgr.got_filesystems) {
		// Search past mounts
		CheckboxGroup xg = new CheckboxGroup();
		Panel xp = new Panel();
		xp.setLayout(new FlowLayout(FlowLayout.LEFT, 1, 1));
		xp.add(xoff = new Checkbox(filemgr.text("yes"), xg, true));
		xp.add(xon = new Checkbox(filemgr.text("no"), xg, false));
		add_item(filemgr.text("search_xdev"), xp, l, r);
		}

	search.add("West", l); search.add("East", r);
	add("Center", tab);

	// Create search and cancel buttons
	Panel bot = new Panel();
	bot.setLayout(new FlowLayout(FlowLayout.RIGHT));
	bot.add(down_b = new CbButton(filemgr.get_image("down.gif"),
				      filemgr.text("search_down"),
				      CbButton.LEFT, this));
	bot.add(search_b = new CbButton(filemgr.get_image("save.gif"),
				      filemgr.text("search_ok"),
				      CbButton.LEFT, this));
	bot.add(cancel_b = new CbButton(filemgr.get_image("cancel.gif"),
					filemgr.text("cancel"),
					CbButton.LEFT, this));
	add("South", bot);
	Util.recursiveBody(this);
	pack();
	show();
	}

	void add_item(String t, Component c, Panel l, Panel r)
	{
	l.add(new Label(t));
	Panel p = new Panel();
	p.setLayout(new BorderLayout());
	p.add("West", c);
	r.add(p);
	}

	public void click(CbButton b)
	{
	if (b == cancel_b)
		dispose();
	else if (b == search_b) {
		// validate inputs and build search URL
		String url = "search.cgi";
		String d = dir.getText().trim();
		if (d.length() == 0 || d.charAt(0) != '/') {
			new ErrorWindow(filemgr.text("search_edir"));
			return;
			}
		url += "?dir="+filemgr.urlize(d);
		String mt = match.getText().trim();
		if (mt.length() == 0) {
			mt = "*";
			//new ErrorWindow(filemgr.text("search_ematch"));
			//return;
			}
		url += "&match="+filemgr.urlize(mt);
		if (type != null && type.getSelectedIndex() > 0)
			url += "&type="+types[type.getSelectedIndex()];
		if (usel != null && usel.getState()) {
			String u = user.getText().trim();
			if (u.length() == 0) {
				new ErrorWindow(filemgr.text("search_euser"));
				return;
				}
			url += "&user="+filemgr.urlize(u);
			}
		if (gsel != null && gsel.getState()) {
			String g = group.getText().trim();
			if (g.length() == 0) {
				new ErrorWindow(filemgr.text("search_egroup"));
				return;
				}
			url += "&group="+filemgr.urlize(g);
			}
		if (smore.getState()) {
			String m = more.getText().trim();
			try { Integer.parseInt(m); }
			catch(Exception e) {
				new ErrorWindow(filemgr.text("search_esize"));
				return;
				}
			url += "&size=%2B"+m+"c";
			}
		else if (sless.getState()) {
			String l = less.getText().trim();
			try { Integer.parseInt(l); }
			catch(Exception e) {
				new ErrorWindow(filemgr.text("search_esize"));
				return;
				}
			url += "&size=%2D"+l+"c";
			}
		if (xon != null && xon.getState())
			url += "&xdev=1";
		if (cont != null && cont.getText().trim().length() > 0)
			url += "&cont="+filemgr.urlize(cont.getText());

		// send off the search
		setCursor(WAIT_CURSOR);
		String f[] = filemgr.get_text(url);
		if (f[0].length() > 0) {
			new ErrorWindow(f[0]);
			return;
			}
		Object rows[][] = new Object[f.length-1][];
		results = new RemoteFile[f.length-1];
		for(int i=1; i<f.length; i++) {
			RemoteFile r = new RemoteFile(filemgr, f[i], null);
			results[i-1] = r;
			Object row[] = rows[i-1] = new Object[3];
			row[0] = filemgr.get_image(RemoteFile.tmap[r.type]);
			row[1] = r.path;
			if (r.size < 1000)
				row[2] = filemgr.spad(r.size, 5)+" B";
			else if (r.size < 1000000)
				row[2] = filemgr.spad(r.size/1000, 5)+" kB";
			else
				row[2] = filemgr.spad(r.size/1000000, 5)+" MB";
			}
		list.clear();
		list.addItems(rows);
		tab.select(filemgr.text("search_list"));
		setCursor(DEFAULT_CURSOR);
		}
	else if (b == down_b) {
		// Download selected file (if any)
		int num = list.selected();
		if (num < 0 || results.length == 0) {
			new ErrorWindow(filemgr.text("search_edown"));
			return;
			}
		filemgr.download_file(results[num]);
		}
	}

	public void singleClick(MultiColumn list, int num)
	{
	}

	// go to the directory of the double-clicked file
	public void doubleClick(MultiColumn list, int num)
	{
	RemoteFile f = results[num];
	int sl = f.path.lastIndexOf('/');
	String dir = sl == 0 ? "/" : f.path.substring(0, sl);
	filemgr.find_directory(dir, true);
	RemoteFile l[] = filemgr.showing_list;
	for(int i=0; i<l.length; i++) {
		if (l[i].name.equals(f.name)) {
			// select the file in the list
			filemgr.files.select(i+1);
			filemgr.files.scrollto(i+1);
			break;
			}
		}
	dispose();
	}

	public void headingClicked(MultiColumn list, int col)
	{
	}
}

// A popup window showing previously entered paths
class HistoryWindow extends FixedFrame
	implements CbButtonCallback,ActionListener
{

	java.awt.List hlist;
	CbButton ok_b, cancel_b;
	FileManager filemgr;

	HistoryWindow(FileManager p)
	{
	filemgr = p;
	setTitle(filemgr.text("history_title"));

	// Setup UI
	hlist = new java.awt.List();
	for(int i=0; i<filemgr.history_list.size(); i++) {
		hlist.add((String)filemgr.history_list.elementAt(i));
		}
	hlist.addActionListener(this);
	setLayout(new BorderLayout());
	add("Center", hlist);
	Panel bot = new Panel();
	bot.setLayout(new FlowLayout(FlowLayout.RIGHT));
	bot.add(ok_b = new CbButton(filemgr.get_image("save.gif"),
				    filemgr.text("history_ok"),
				    CbButton.LEFT, this));
	bot.add(cancel_b = new CbButton(filemgr.get_image("cancel.gif"),
                                        filemgr.text("cancel"),
                                        CbButton.LEFT, this));
	add("South", bot);
        Util.recursiveBody(this);
        pack();
        show();
	}

	public void click(CbButton b)
	{
	if (b == cancel_b)
		dispose();
	else if (b == ok_b) {
		// Go to the selected directory
		String p = hlist.getSelectedItem();
		if (p != null) {
			filemgr.find_directory(p, true);
			dispose();
			}
		}
	}

	public void actionPerformed(ActionEvent e)
	{
	// List entry double-clicked .. go to it
	String p = hlist.getSelectedItem();
	filemgr.find_directory(p, true);
	dispose();
	}

	public Dimension minimumSize()
	{
	return new Dimension(300, 300);
	}
}

class FileSystem
{
	String mount;
	String dev;
	String type;
	String opts[];
	boolean acls;
	boolean attrs;
	boolean ext;
	boolean mtab, fstab;

	FileSystem(String l)
	{
	StringSplitter tok = new StringSplitter(l, ' ');
	mount = tok.nextToken();
	dev = tok.nextToken();
	type = tok.nextToken();
	String optstr = tok.nextToken();
	acls = tok.nextToken().equals("1");
	attrs = tok.nextToken().equals("1");
	ext = tok.nextToken().equals("1");
	mtab = tok.nextToken().equals("1");
	fstab = tok.nextToken().equals("1");

	StringTokenizer tok2 = new StringTokenizer(optstr, ",");
	opts = new String[tok2.countTokens()];
	for(int i=0; i<opts.length; i++)
		opts[i] = tok2.nextToken();
	}
}

class ACLEntry
{
	FileManager filemgr;
	RemoteFile file;
	boolean def;
	String type;
	String owner;
	boolean read, write, exec;
	boolean empty_owner = false;

	ACLEntry(String l, ACLWindow w)
	{
	filemgr = w.filemgr;
	file = w.file;
	StringSplitter tok = new StringSplitter(l, ':');
	type = tok.nextToken();
	if (type.equals("default")) {
		def = true;
		type = tok.nextToken();
		}
	if (!type.equals("mask") && !type.equals("other")) {
		owner = tok.nextToken();
		if (owner.length() == 0)
			owner = null;
		}
	String rwx = tok.nextToken();
	if (rwx.length() == 0) {
		rwx = tok.nextToken();	// getfacl outputs a blank owner for
					// mask and other on some systems
		empty_owner = true;
		}
	read = (rwx.charAt(0) == 'r');
	write = (rwx.charAt(1) == 'w');
	exec = (rwx.charAt(2) == 'x');
	}

	ACLEntry(ACLWindow w)
	{
	filemgr = w.filemgr;
	file = w.file;
	}

	String[] getRow()
	{
	String rv[] = new String[3];
	String t = def ? "acltype_default_"+type : "acltype_"+type;
	rv[0] = filemgr.text(t);
	if (type.equals("mask") || type.equals("other") ||
	    (def && owner == null))
		rv[1] = "";
	else if (owner != null)
		rv[1] = owner;
	else if (type.equals("user"))
		rv[1] = filemgr.text("eacl_user", file.user);
	else
		rv[1] = filemgr.text("eacl_group", file.group);
	rv[2] = "";
	if (read) rv[2] += filemgr.text("info_read")+" ";
	if (write) rv[2] += filemgr.text("info_write")+" ";
	if (exec) rv[2] += filemgr.text("info_exec")+" ";
	return rv;
	}

	public String toString()
	{
	String rv = def ? "default:" : "";
	rv += type+":";
	if (!type.equals("mask") && !type.equals("other") || empty_owner)
		// mask and other types have no owner field at all, except
		// on some operating systems like FreeBSD where it is empty
		rv += (owner == null ? "" : owner)+":";
	rv += (read ? 'r' : '-');
	rv += (write ? 'w' : '-');
	rv += (exec ? 'x' : '-');
	return rv;
	}
}

class ACLEditor extends FixedFrame implements CbButtonCallback
{
	FileManager filemgr;
	ACLWindow aclwin;
	ACLEntry acl;
	boolean creating;
	CbButton ok, del;
	Checkbox read, write, exec, owner1, owner2;
	TextField owner;

	// Editing an existing ACL entry
	ACLEditor(ACLWindow w, ACLEntry a)
	{
	aclwin = w;
	filemgr = aclwin.filemgr;
	acl = a;
	creating = false;
	makeUI();
	}

	// Creating a new ACL entry
	ACLEditor(ACLWindow w, String type, boolean def, boolean empty_owner)
	{
	aclwin = w;
	filemgr = aclwin.filemgr;
	acl = new ACLEntry(aclwin);
	acl.def = def;
	acl.type = type;
	acl.empty_owner = empty_owner;
	creating = true;
	makeUI();
	}

	void makeUI()
	{
	setTitle(filemgr.text(creating ? "eacl_create" : "eacl_edit"));
	setLayout(new BorderLayout());
	Panel left = new Panel();
	left.setLayout(new GridLayout(0, 1));
	add("West", left);
	Panel right = new Panel();
	right.setLayout(new GridLayout(0, 1));
	add("East", right);

	left.add(new Label(filemgr.text("eacl_acltype")));
	TextField type;
	right.add(type = new TextField(
				(acl.def ? "default " : "")+acl.type, 20));
	type.setEditable(false);
	type.setFont(filemgr.fixed);

	if (!acl.type.equals("mask") && !acl.type.equals("other")) {
		left.add(new Label(filemgr.text("eacl_aclname")));
		if (acl.def) {
			// A default user or group ACL .. can be for
			// a specific user, or for the file owner
			Panel op = new Panel();
			op.setLayout(new FlowLayout(FlowLayout.LEFT, 0, 0));
			CheckboxGroup gr = new CheckboxGroup();
			op.add(owner1 = new Checkbox(filemgr.text("eacl_owner"),
					    gr, acl.owner == null));
			op.add(owner2 = new Checkbox("",
					    gr, acl.owner != null));
			op.add(owner = new TextField(
				acl.owner == null ? "" : acl.owner, 20));
			owner.setFont(filemgr.fixed);
			right.add(op);
			}
		else if (creating || acl.owner != null) {
			// A user or group ACL for a specific user
			owner = new TextField(
					acl.owner == null ? "" : acl.owner, 20);
			owner.setFont(filemgr.fixed);
			right.add(owner);
			}
		else {
			// A user or group ACL for the file owner
			String str;
			if (acl.type.equals("user"))
			    str = filemgr.text("eacl_user", aclwin.file.user);
			else
			    str = filemgr.text("eacl_group", aclwin.file.group);
			TextField o = new TextField(str);
			o.setEditable(false);
			o.setFont(filemgr.fixed);
			right.add(o);
			}
		}

	left.add(new Label(filemgr.text("eacl_aclperms")));
	Panel pp = new Panel();
	pp.setLayout(new FlowLayout(FlowLayout.RIGHT));
	pp.add(read = new Checkbox(filemgr.text("info_read"), null, acl.read));
	pp.add(write = new Checkbox(filemgr.text("info_write"), null, acl.write));
	pp.add(exec = new Checkbox(filemgr.text("info_exec"), null, acl.exec));
	right.add(pp);

	Panel bot = new Panel();
	bot.setLayout(new FlowLayout(FlowLayout.RIGHT));
	bot.add(ok = new CbButton(filemgr.get_image("save.gif"),
				  filemgr.text("save"),
				  CbButton.LEFT, this));
	if (!creating && (acl.owner != null || acl.def))
		bot.add(del = new CbButton(filemgr.get_image("cancel.gif"),
					   filemgr.text("delete"),
					   CbButton.LEFT, this));
	add("South", bot);

	Util.recursiveBody(this);
	pack();
	show();
	}

	public void click(CbButton b)
	{
	if (b == ok) {
		// Update or add the ACL entry
		if (owner1 != null && owner1.getState()) {
			acl.owner = null;
			}
		else if (owner != null) {
			String o = owner.getText().trim();
			if (o.length() == 0 && !acl.def) {
				new ErrorWindow(filemgr.text("eacl_eowner"));
				return;
				}
			acl.owner = owner.getText();
			if (acl.owner.length() == 0)
				acl.owner = null;
			}
		acl.read = read.getState();
		acl.write = write.getState();
		acl.exec = exec.getState();
		if (creating) {
			// Add to the ACL table
			aclwin.acllist.addElement(acl);
			aclwin.acltable.addItem(acl.getRow());
			}
		else {
			// Update the table
			int idx = aclwin.acllist.indexOf(acl);
			aclwin.acltable.modifyItem(acl.getRow(), idx);
			}
		dispose();
		}
	else if (b == del) {
		// Remove this entry
		int idx = aclwin.acllist.indexOf(acl);
		aclwin.acllist.removeElementAt(idx);
		aclwin.acltable.deleteItem(idx);
		dispose();
		}
	}

	public void dispose()
	{
	aclwin.edmap.remove(acl);
	super.dispose();
	}
}

class ACLWindow extends FixedFrame implements CbButtonCallback,MultiColumnCallback
{
	FileManager filemgr;
	RemoteFile file;
	Vector acllist = new Vector();
	Hashtable edmap = new Hashtable();

	CbButton ok, cancel, add;
	Choice addtype;
	MultiColumn acltable;

	String acltypes[] = { "user", "group", "mask",
			      "default user", "default group", "default other",
			      "default mask" };

	ACLWindow(FileManager p, RemoteFile f)
	{
	super(400, 300);
	setTitle(p.text("eacl_title", f.path));
	filemgr = p;
	file = f;

	// Get the ACLs
	String a[] = filemgr.get_text(
			"getfacl.cgi?file="+filemgr.urlize(file.path));
	if (a[0].length() != 0) {
		new ErrorWindow(filemgr.text("eacl_eacls", a[0]));
		return;
		}

	// Create the UI
	setLayout(new BorderLayout());
	String titles[] = { filemgr.text("eacl_acltype"),
			    filemgr.text("eacl_aclname"),
			    filemgr.text("eacl_aclperms") };
	acltable = new MultiColumn(titles, this);
	for(int i=1; i<a.length; i++) {
		ACLEntry acl = new ACLEntry(a[i], this);
		acllist.addElement(acl);
		acltable.addItem(acl.getRow());
		}
	add("Center", acltable);
	Panel abot = new Panel();
	abot.setLayout(new FlowLayout(FlowLayout.RIGHT));
	abot.add(add = new CbButton(filemgr.get_image("add.gif"),
				   filemgr.text("eacl_add"),
				   CbButton.LEFT, this));
	int len = file.type == RemoteFile.DIR ? acltypes.length : 3;
	abot.add(addtype = new Choice());
	for(int i=0; i<len; i++) {
		String t = "acltype_"+acltypes[i].replace(' ', '_');
		addtype.addItem(filemgr.text(t));
		}
	abot.add(new Label(" "));
	abot.add(ok = new CbButton(filemgr.get_image("save.gif"),
				   filemgr.text("save"),
				   CbButton.LEFT, this));
	abot.add(cancel = new CbButton(filemgr.get_image("cancel.gif"),
				       filemgr.text("cancel"),
				       CbButton.LEFT, this));
	add("South", abot);

	Util.recursiveBody(this);
	pack();
	show();
	}

	public void click(CbButton b)
	{
	if (b == ok) {
		// Check if there are any defaults, and if so there must
		// be default user, group and other
		boolean anydef = false, defuser = false,
			defgroup = false, defother = false;
		for(int i=0; i<acllist.size(); i++) {
			ACLEntry e = (ACLEntry)acllist.elementAt(i);
			if (e.def) anydef = true;
			if (e.def && e.owner == null) {
				if (e.type.equals("user")) defuser = true;
				if (e.type.equals("group")) defgroup = true;
				if (e.type.equals("other")) defother = true;
				}
			}
		if (anydef && (!defuser || !defgroup || !defother)) {
			new ErrorWindow(filemgr.text("eacl_edefaults"));
			return;
			}

		// Save the ACLs
		String aclstr = "";
		for(int i=0; i<acllist.size(); i++)
			aclstr += (ACLEntry)acllist.elementAt(i)+"\n";
		String rv[] = filemgr.get_text("setfacl.cgi?file="+
						filemgr.urlize(file.path)+
						"&acl="+filemgr.urlize(aclstr));
		if (rv[0].length() > 0)
			new ErrorWindow(filemgr.text("eacl_efailed",
				file.path, rv[0]));
		else
			dispose();
		}
	else if (b == add) {
		// Open a window for a new ACL entry
		String t = acltypes[addtype.getSelectedIndex()];
		String d = "default ";
		boolean def = t.startsWith(d);
		if (def)
			t = t.substring(d.length());
		if (t.equals("mask")) {
			// Only allow one mask
			for(int i=0; i<acllist.size(); i++) {
				ACLEntry a = (ACLEntry)acllist.elementAt(i);
				if (a.type.equals(t) && a.def == def) {
					new ErrorWindow(filemgr.text(def ?
					    "eacl_edefmask" : "eacl_emask"));
					return;
					}
				}
			}
		// Check if owner field exists and is empty for existing
		// mask or other fields
		boolean new_empty_owner = false;
		for(int i=0; i<acllist.size(); i++) {
			ACLEntry a = (ACLEntry)acllist.elementAt(i);
			if ((a.type.equals("mask") || a.type.equals("other")) &&
			   a.empty_owner) {
				new_empty_owner = true;
				}
			}
		new ACLEditor(this, t, def, new_empty_owner);
		}
	else if (b == cancel) {
		// Don't save
		dispose();
		}
	}

	// Bring up an editor for an ACL
        public void doubleClick(MultiColumn list, int num)
	{
	int idx = list.selected();
	if (idx >= 0) {
		ACLEntry e = (ACLEntry)acllist.elementAt(idx);
		ACLEditor ed = (ACLEditor)edmap.get(e);
		if (ed == null)
			edmap.put(e, new ACLEditor(this, e));
		else {
			ed.toFront();
			ed.requestFocus();
			}
		}
	}

        public void singleClick(MultiColumn list, int num)
	{
	}

	public void headingClicked(MultiColumn list, int col)
	{
	}
}

class AttributesWindow extends FixedFrame
	implements CbButtonCallback,MultiColumnCallback
{
	FileManager filemgr;
	RemoteFile file;
	Vector attrlist = new Vector();
	Hashtable edmap = new Hashtable();

	CbButton ok, cancel, add;
	MultiColumn attrtable;

	AttributesWindow(FileManager p, RemoteFile f)
	{
	super(400, 300);
	setTitle(p.text("attr_title", f.path));
	filemgr = p;
	file = f;

	// Get the attributes
	String a[] = filemgr.get_text(
			"getattrs.cgi?file="+filemgr.urlize(file.path));
	if (a[0].length() != 0) {
		new ErrorWindow(filemgr.text("attr_eattrs", a[0]));
		return;
		}

	// Create the UI
	setLayout(new BorderLayout());
	String titles[] = { filemgr.text("attr_name"),
			    filemgr.text("attr_value") };
	attrtable = new MultiColumn(titles, this);
	for(int i=1; i<a.length; i++) {
		FileAttribute at = new FileAttribute(a[i], filemgr);
		attrlist.addElement(at);
		attrtable.addItem(at.getRow());
		}
	add("Center", attrtable);
	Panel abot = new Panel();
	abot.setLayout(new FlowLayout(FlowLayout.RIGHT));
	abot.add(add = new CbButton(filemgr.get_image("add.gif"),
				   filemgr.text("attr_add"),
				   CbButton.LEFT, this));
	abot.add(new Label(" "));
	abot.add(ok = new CbButton(filemgr.get_image("save.gif"),
				   filemgr.text("save"),
				   CbButton.LEFT, this));
	abot.add(cancel = new CbButton(filemgr.get_image("cancel.gif"),
				       filemgr.text("cancel"),
				       CbButton.LEFT, this));
	add("South", abot);

	Util.recursiveBody(this);
	pack();
	show();
	}

	public void click(CbButton b)
	{
	if (b == ok) {
		// Save the attributes
		String pstr = "";
		for(int i=0; i<attrlist.size(); i++) {
			FileAttribute at = (FileAttribute)attrlist.elementAt(i);
			pstr += "&name"+i+"="+filemgr.urlize(at.name)+
			        "&value"+i+"="+filemgr.urlize(at.value);
			}
		String rv[] = filemgr.get_text("setattrs.cgi?file="+
						filemgr.urlize(file.path)+pstr);
		if (rv[0].length() > 0)
			new ErrorWindow(filemgr.text("attr_efailed",
				file.path, rv[0]));
		else
			dispose();
		}
	else if (b == add) {
		// Open a window for a new ACL entry
		new AttributeEditor(this);
		}
	else if (b == cancel) {
		// Don't save
		dispose();
		}
	}

	// Bring up an editor for an ACL
        public void doubleClick(MultiColumn list, int num)
	{
	int idx = list.selected();
	if (idx >= 0) {
		FileAttribute at = (FileAttribute)attrlist.elementAt(idx);
		AttributeEditor ed = (AttributeEditor)edmap.get(at);
		if (ed == null)
			edmap.put(at, new AttributeEditor(this, at));
		else {
			ed.toFront();
			ed.requestFocus();
			}
		}
	}

        public void singleClick(MultiColumn list, int num)
	{
	}

	public void headingClicked(MultiColumn list, int col)
	{
	}
}

class FileAttribute
{
	String name;
	String value;

	FileAttribute(String l, FileManager f)
	{
	int eq = l.indexOf('=');
	name = f.un_urlize(l.substring(0, eq));
	value = f.un_urlize(l.substring(eq+1));
	}

	FileAttribute(String n, String v)
	{
	name = n;
	value = v;
	}

	String[] getRow()
	{
	return new String[] { name, value };
	}
}

class AttributeEditor extends FixedFrame implements CbButtonCallback
{
	FileManager filemgr;
	AttributesWindow attrwin;
	FileAttribute attr;
	boolean creating;
	CbButton ok, del;
	TextField name;
	TextArea value;

	AttributeEditor(AttributesWindow w, FileAttribute a)
	{
	attrwin = w;
	attr = a;
	filemgr = w.filemgr;
	creating = false;
	makeUI();
	}

	AttributeEditor(AttributesWindow w)
	{
	attrwin = w;
	attr = new FileAttribute("", "");
	filemgr = w.filemgr;
	creating = true;
	makeUI();
	}

	void makeUI()
	{
	setTitle(filemgr.text(creating ? "attr_create" : "attr_edit"));
	setLayout(new BorderLayout());

	Panel top = new Panel();
	top.setLayout(new GridLayout(1, 2));
	top.add(new Label(filemgr.text("attr_name")));
	top.add(name = new TextField(attr.name, 20));
	name.setFont(filemgr.fixed);
	add("North", top);

	Panel mid = new Panel();
	mid.setLayout(new GridLayout(1, 2));
	mid.add(new Label(filemgr.text("attr_value")));
	mid.add(value = new TextArea(attr.value, 5, 20));
	add("Center", mid);

	Panel bot = new Panel();
	bot.setLayout(new FlowLayout(FlowLayout.RIGHT));
	bot.add(ok = new CbButton(filemgr.get_image("save.gif"),
				  filemgr.text("save"),
				  CbButton.LEFT, this));
	if (!creating)
		bot.add(del = new CbButton(filemgr.get_image("cancel.gif"),
					   filemgr.text("delete"),
					   CbButton.LEFT, this));
	add("South", bot);

	Util.recursiveBody(this);
	pack();
	show();
	}

	public void click(CbButton b)
	{
	if (b == ok) {
		// Update or add the attribute
		if (name.getText().length() == 0) {
			new ErrorWindow(filemgr.text("attr_ename"));
			return;
			}
		attr.name = name.getText();
		attr.value = value.getText();
		if (creating) {
			// Add to the attribs table
			attrwin.attrlist.addElement(attr);
			attrwin.attrtable.addItem(attr.getRow());
			}
		else {
			// Update the table
			int idx = attrwin.attrlist.indexOf(attr);
			attrwin.attrtable.modifyItem(attr.getRow(), idx);
			}
		dispose();
		}
	else if (b == del) {
		// Remove this entry
		int idx = attrwin.attrlist.indexOf(attr);
		attrwin.attrlist.removeElementAt(idx);
		attrwin.attrtable.deleteItem(idx);
		dispose();
		}
	}

	public void dispose()
	{
	attrwin.edmap.remove(attr);
	super.dispose();
	}
}

class EXTWindow extends FixedFrame implements CbButtonCallback
{
	FileManager filemgr;
	RemoteFile file;

	CbButton ok, cancel;
	Checkbox cbs[];

	String attrs[] = { "A", "a", "c", "d", "i", "s", "S", "u" };
	Hashtable attrmap = new Hashtable();

	EXTWindow(FileManager p, RemoteFile f)
	{
	super();
	setTitle(p.text("ext_title", f.path));
	filemgr = p;
	file = f;

	// Get the attributes
	String a[] = filemgr.get_text(
			"getext.cgi?file="+filemgr.urlize(file.path));
	if (a[0].length() != 0) {
		new ErrorWindow(filemgr.text("ext_eattrs", a[0]));
		return;
		}
	for(int i=0; i<a[1].length(); i++)
		attrmap.put(a[1].substring(i, i+1), "");

	// Create the UI
	setLayout(new BorderLayout());
	Panel top = new LinedPanel(filemgr.text("ext_header"));
	top.setLayout(new GridLayout(0, 1));
	cbs = new Checkbox[attrs.length];
	for(int i=0; i<attrs.length; i++) {
		cbs[i] = new Checkbox(filemgr.text("eattr_"+attrs[i]));
		cbs[i].setState(attrmap.get(attrs[i]) != null);
		top.add(cbs[i]);
		}
	add("Center", top);

	Panel bot = new Panel();
	bot.setLayout(new FlowLayout(FlowLayout.RIGHT));
	bot.add(ok = new CbButton(filemgr.get_image("save.gif"),
				  filemgr.text("save"),
				  CbButton.LEFT, this));
	bot.add(cancel = new CbButton(filemgr.get_image("cancel.gif"),
				      filemgr.text("cancel"),
				      CbButton.LEFT, this));
	add("South", bot);

	Util.recursiveBody(this);
	pack();
	show();
	}

	public void click(CbButton b)
	{
	if (b == ok) {
		// Save the attributes (including unknown ones)
		String astr = "";
		for(int i=0; i<cbs.length; i++) {
			if (cbs[i].getState())
				astr += attrs[i];
			attrmap.remove(attrs[i]);
			}
		for(Enumeration e = attrmap.keys(); e.hasMoreElements(); )
			astr += e.nextElement();

		// Try to set on the server
		String rv[] = filemgr.get_text("setext.cgi?file="+
				filemgr.urlize(file.path)+"&attrs="+astr);
		if (rv[0].length() > 0)
			new ErrorWindow(filemgr.text("ext_efailed",
				file.path, rv[0]));
		else
			dispose();
		}
	else if (b == cancel) {
		dispose();
		}
	}
}

class MountWindow extends FixedFrame implements CbButtonCallback
{
	CbButton yes, no;
	FileManager filemgr;
	FileSystem fs;
	RemoteFile file;

	MountWindow(FileManager filemgr, FileSystem fs, RemoteFile file)
	{
	super();
	setTitle(filemgr.text(fs.mtab ? "mount_title2" : "mount_title1"));
	this.filemgr = filemgr;
	this.fs = fs;
	this.file = file;

	// Create the UI
	setLayout(new BorderLayout());
	Panel cen = new BorderPanel(1, Util.body);
	cen.setLayout(new GridLayout(1, 1));
	String rusure = fs.mtab ? "mount_rusure2" : "mount_rusure1";
	cen.add(new Label(filemgr.text(rusure, fs.mount, fs.dev)));
	add("Center", cen);
	Panel bot = new Panel();
	bot.setLayout(new FlowLayout(FlowLayout.CENTER));
	bot.add(yes = new CbButton(filemgr.text("yes"), this));
	bot.add(no = new CbButton(filemgr.text("no"), this));
	add("South", bot);
	pack();
	show();
	Util.recursiveBody(this);
	}

	public void click(CbButton b)
	{
	if (b == yes) {
		// Go ahread and do it!
		String rv[] = filemgr.get_text("mount.cgi?dir="+
					       filemgr.urlize(fs.mount));
		dispose();
		if (rv[0].equals("")) {
			// It worked - refresh this directory and the mount list
			filemgr.get_filesystems();
			FileNode d = (FileNode)filemgr.nodemap.get(file);
			if (d != null) {
				d.setimage();
				d.known = false;
				d.file.list = null;
				d.fill();
				}
			if (fs.mtab)
				filemgr.show_files(file.directory);
			else
				filemgr.show_files(filemgr.showing_files);
			}
		else {
			// Failed - show the error
			new ErrorWindow(filemgr.text(
				fs.mtab ? "mount_err2" : "mount_err1",
				fs.mount, rv[0]));
			}
		}
	else {
		// Just close the window
		dispose();
		}
	}
}

// A label that is limited to a maximum number of characters wide
class MultiLabel extends BorderPanel
{
	public MultiLabel(String s, int max)
	{
	this(s, max, 1);
	}

	public MultiLabel(String s, int max, int b)
	{
	this(s, max, b, Label.CENTER);
	}

	
	public MultiLabel(String s, int max, int b, int align)
	{
	super(b, Util.body);
	Vector v = new Vector();
	StringTokenizer tok = new StringTokenizer(s.trim(), " \t");
	String line = null;
	while(tok.hasMoreTokens()) {
		String w = tok.nextToken();
		line = (line == null ? w : line+" "+w);
		if (line.length() > max || !tok.hasMoreTokens()) {
			v.addElement(line);
			line = null;
			}
		}
	setLayout(new GridLayout(v.size(), 1, 0, 0));
	for(int i=0; i<v.size(); i++) {
		Label l = new Label((String)v.elementAt(i), Label.CENTER);
		add(l);
		}
	}
}

// A window for choosing the format in which a directory will be downloaded
class DownloadDirWindow extends FixedFrame implements CbButtonCallback
{
	CbButton zip, tgz, tar, cancel;
	FileManager filemgr;
	RemoteFile file;

	DownloadDirWindow(FileManager filemgr, RemoteFile file)
	{
	super();
	setTitle(filemgr.text("ddir_title"));
	this.filemgr = filemgr;
	this.file = file;

	// Create the UI
	setLayout(new BorderLayout());
	Panel cen = new BorderPanel(1, Util.body);
	cen.setLayout(new GridLayout(1, 1));
	cen.add(new Label(filemgr.text("ddir_rusure", file.path)));
	add("Center", cen);

	Panel bot = new Panel();
	bot.setLayout(new FlowLayout(FlowLayout.CENTER));
	bot.add(zip = new CbButton(filemgr.text("ddir_zip"), this));
	bot.add(tgz = new CbButton(filemgr.text("ddir_tgz"), this));
	bot.add(tar = new CbButton(filemgr.text("ddir_tar"), this));
	bot.add(cancel = new CbButton(filemgr.text("cancel"), this));
	add("South", bot);
	pack();
	show();
	Util.recursiveBody(this);
	}

	public void click(CbButton b)
	{
	if (b == cancel) {
		// just close the window
		dispose();
		}
	else {
		// open the download window
		int format = b == zip ? 1 :
			     b == tgz ? 2 : 3;
		dispose();
		filemgr.open_file_window(file, true, format);
		}
	}
}

class PreviewWindow extends Frame implements CbButtonCallback
{
	CbButton close_b;
	RemoteFile file;
	FileManager filemgr;
	ImagePanel ip;

	// Previewing a file
	public PreviewWindow(FileManager p, RemoteFile f)
	{
	//super(350, 350);
	file = f; filemgr = p;
	makeUI();
	setTitle(filemgr.text("preview_title", file.path));

	// Load the file
	try {
		URL u = new URL(filemgr.getDocumentBase(),
				"preview.cgi"+filemgr.urlize(file.path)+
				"?rand="+System.currentTimeMillis()+
				"&trust="+filemgr.trust+
				filemgr.extra);
		URLConnection uc = u.openConnection();
		filemgr.set_cookie(uc);
		int len = uc.getContentLength();
		InputStream is = uc.getInputStream();
		byte buf[];
		if (len >= 0) {
			// Length is known
			buf = new byte[uc.getContentLength()];
			int got = 0;
			while(got < buf.length)
				got += is.read(buf, got, buf.length-got);
			}
		else {
			// Length is unknown .. read till the end
			buf = new byte[0];
			while(true) {
			    byte data[] = new byte[16384];
			    int got;
			    try { got = is.read(data); }
			    catch(EOFException ex) { break; }
			    if (got <= 0) break;
			    byte nbuf[] = new byte[buf.length + got];
			    System.arraycopy(buf, 0, nbuf, 0, buf.length);
			    System.arraycopy(data, 0, nbuf, buf.length, got);
			    buf = nbuf;
			    }
			}

		// Check if this is really an error
		if (uc.getContentType().equals("text/plain")) {
			String s = new String(buf, 0);
			new ErrorWindow(s);
			dispose();
			return;
			}

		// Show the image
		Image img = Toolkit.getDefaultToolkit().createImage(buf);
                MediaTracker waiter = new MediaTracker(this);
                waiter.addImage(img, 666);
                try { waiter.waitForAll(); }
                catch(InterruptedException e) { }
		if (img.getWidth(this) <= 0) {
			new ErrorWindow(filemgr.text("preview_bad"));
			dispose();
			return;
			}
		ip.setImage(img);

		pack();
		show();
		}
	catch(Exception e) { e.printStackTrace(); }
	}

	void makeUI()
	{
	setLayout(new BorderLayout());

	// Image viewing area
	BorderPanel mid = new BorderPanel(2, Util.body);
	mid.setLayout(new BorderLayout());
	ip = new ImagePanel(null);
	mid.add("Center", ip);
	add("Center", mid);

	// Button panel
	Panel bot = new Panel();
	bot.setLayout(new FlowLayout(FlowLayout.RIGHT));
	bot.add(close_b = new CbButton(filemgr.get_image("cancel.gif"),
					filemgr.text("close"),
					CbButton.LEFT, this));
	add("South", bot);
	Util.recursiveBody(this);
	}

	public void click(CbButton b)
	{
	if (b == close_b) {
		// Just close
		dispose();
		}
	}
}

class ImagePanel extends Panel
{
	Image img;

	public ImagePanel(Image img)
	{
	this.img = img;
	}

	public void paint(Graphics g)
	{
	if (img != null) {
		g.drawImage(img, 0, 0, this);
		}
	}

	public void setImage(Image img)
	{
	this.img = img;
	repaint();
	}

	public Dimension minimumSize()
	{
	return new Dimension(img.getWidth(this), img.getHeight(this));
	}

	public Dimension preferredSize()
	{
	return minimumSize();
	}
}

class ExtractWindow extends FixedFrame implements CbButtonCallback
{
	CbButton yes, yesdelete, no, show;
	FileManager filemgr;
	RemoteFile file;

	ExtractWindow(FileManager filemgr, RemoteFile file)
	{
	super();
	setTitle(filemgr.text("extract_title"));
	this.filemgr = filemgr;
	this.file = file;

	// Create the UI
	setLayout(new BorderLayout());
	Panel cen = new BorderPanel(1, Util.body);
	cen.setLayout(new GridLayout(3, 1));
	cen.add(new Label(filemgr.text("extract_rusure")));
	cen.add(new Label(file.path));
	cen.add(new Label(filemgr.text("extract_rusure2")));
	add("Center", cen);
	Panel bot = new Panel();
	bot.setLayout(new FlowLayout(FlowLayout.CENTER));
	bot.add(yes = new CbButton(filemgr.text("yes"), this));
	bot.add(yesdelete = new CbButton(filemgr.text("extract_yes"), this));
	bot.add(no = new CbButton(filemgr.text("no"), this));
	bot.add(show = new CbButton(filemgr.text("extract_show"), this));
	add("South", bot);
	pack();
	show();
	Util.recursiveBody(this);
	}

	public void click(CbButton b)
	{
	if (b == yes || b == yesdelete) {
		// Go ahread and do it!
		String rv[] = filemgr.get_text("extract.cgi?file="+
				       filemgr.urlize(file.path)+
				       "&delete="+(b == yesdelete ? 1 : 0));
		dispose();
		if (rv[0].equals("")) {
			// It worked - refresh the directory
			RemoteFile par = file.directory;
			FileNode d = (FileNode)filemgr.nodemap.get(par);
			if (d != null) {
				d.setimage();
				d.known = false;
				d.file.list = null;
				d.fill();
				}
			filemgr.show_files(filemgr.showing_files);
			}
		else {
			// Failed - show the error
			new ErrorWindow(filemgr.text("extract_err", rv[0]));
			}
		}
	else if (b == show) {
		// Open window just showing contents
		String rv[] = filemgr.get_text("contents.cgi?file="+
				       	       filemgr.urlize(file.path));
		dispose();
		if (rv[0].equals("")) {
			// Worked - show the files
			new ContentsWindow(file, filemgr, rv);
			}
		else {
			// Failed - show the error
			new ErrorWindow(filemgr.text("extract_err2", rv[0]));
			}
		}
	else {
		// Just close the window
		dispose();
		}
	}
}

class ContentsWindow extends FixedFrame implements CbButtonCallback
{
	RemoteFile file;
        FileManager filemgr;
        CbButton close_b;

	ContentsWindow(RemoteFile f, FileManager p, String rv[])
	{
	file = f;
	filemgr = p;

	// Create UI
	setTitle(f.path);
	setLayout(new BorderLayout());
	Panel bot = new Panel();
	bot.setLayout(new FlowLayout(FlowLayout.RIGHT));
	bot.add(close_b = new CbButton(filemgr.get_image("cancel.gif"),
					filemgr.text("close"),
					CbButton.LEFT, this));
	add("South", bot);

	// Create text area showing contents
	String lines = "";
	for(int i=1; i<rv.length; i++) {
		lines = lines + rv[i] + "\n";
		}
	TextArea contents = new TextArea(lines, 30, 60);
	contents.setEditable(false);
	add("Center", contents);
	add("North", new Label(filemgr.text("extract_shown")));

	Util.recursiveBody(this);
	pack();
	show();
	}

	public void click(CbButton b)
	{
	if (b == close_b) {
		// Just close
		dispose();
		}
	}
}

