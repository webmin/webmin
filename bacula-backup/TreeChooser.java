import java.awt.*;
import java.io.*;
import java.applet.*;
import java.net.*;
import java.util.*;
import netscape.javascript.JSObject;

public class TreeChooser extends Applet
	implements CbButtonCallback, HierarchyCallback
{
	CbButton add_b, remove_b, close_b;
	Hierarchy tree;
	BaculaNode root;
	String volume;
	String session;
	String job;
	Vector added = new Vector();

	public void init()
	{
	// Create the root
	String rpath = getParameter("root");
	root = new BaculaNode(this, rpath, true, null);
	volume = getParameter("volume");
	session = getParameter("session");
	job = getParameter("job");

	// Build the UI
	setLayout(new BorderLayout());
	BorderPanel top = new BorderPanel(2);
	top.setLayout(new FlowLayout(FlowLayout.LEFT));
	top.add(add_b = new CbButton("Add", this));
	top.add(remove_b = new CbButton("Remove", this));
	top.add(close_b = new CbButton("Close", this));
	add("North", top);
	add("Center", tree = new Hierarchy(root, this));
	}

        Image get_image(String img)
        {
        return getImage(getDocumentBase(), "images/"+img);
        }

        String[] get_text(String url)
        {
	Cursor orig = getCursor();
        try {
		Cursor busy = Cursor.getPredefinedCursor(Cursor.WAIT_CURSOR);
		setCursor(busy);
                long now = System.currentTimeMillis();
                if (url.indexOf('?') > 0) url += "&rand="+now;
                else url += "?rand="+now;
                URL u = new URL(getDocumentBase(), url);
                URLConnection uc = u.openConnection();
		set_cookie(uc);
                String charset = get_charset(uc.getContentType());
                BufferedReader is = new BufferedReader(
                        (charset == null) ?
                        new InputStreamReader(uc.getInputStream()) :
                        new InputStreamReader(uc.getInputStream(), charset));
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
                String err[] = { e.getMessage() };
                return err;
                }
	finally {
		setCursor(orig);
		}
        }

	void set_cookie(URLConnection conn)
	{
	if (session != null)
		conn.setRequestProperty("Cookie", session);
	}

        // Gets charset parameter from Content-Type: header
        String get_charset(String ct)
        {
        if (ct == null)
                return null;
        StringTokenizer st = new StringTokenizer(ct, ";");
        while (st.hasMoreTokens()) {
                String l = st.nextToken().trim().toLowerCase();
                if (l.startsWith("charset=")) {
                        // get the value of charset= param.
                        return l.substring(8);
                        }
                }
        return null;
        }

	public void openNode(Hierarchy h, HierarchyNode n)
	{
	// Get the files under this directory, and expand the tree
	BaculaNode bn = (BaculaNode)n;
	bn.fill();
	}

	public void closeNode(Hierarchy h, HierarchyNode n)
	{
	// No need to do anything
	}

	public void clickNode(Hierarchy h, HierarchyNode n)
	{
	// Also no need to do anything
	}

	public void doubleNode(Hierarchy h, HierarchyNode n)
	{
	// add or remove a file
	BaculaNode sel = (BaculaNode)n;
	if (sel.added) remove_node(sel);
	else add_node(sel);
	}

	public void click(CbButton b)
	{
	BaculaNode sel = (BaculaNode)tree.selected();
	if (b == close_b) {
		// Close the window, and update the text box
		try {
			JSObject win = JSObject.getWindow(this);
			String params1[] = { "" };
			win.call("clear_files", params1);
			for(int i=0; i<added.size(); i++) {
				BaculaNode n = (BaculaNode)added.elementAt(i);
				String params2[] = { n.path };
				if (n.isdir && !n.path.equals("/"))
					params2[0] = n.path+"/";
				win.call("add_file", params2);
				}
			String params3[] = { "" };
			win.call("finished", params3);
			}
		catch(Exception e) {
			e.printStackTrace();
			new ErrorWindow("Failed to set files : "+
					e.getMessage());
			}
		}
	else if (b == add_b) {
		// Flag the selected file as added
		if (sel != null) {
			add_node(sel);
			}
		}
	else if (b == remove_b) {
		// Un-flag the selected file
		if (sel != null) {
			remove_node(sel);
			}
		}
	}

	void add_node(BaculaNode n)
	{
	if (!n.added) {
		n.added = true;
		n.set_all_icons();
		tree.redraw();
		added.addElement(n);
		}
	}

	void remove_node(BaculaNode n)
	{
	if (n.added) {
		n.added = false;
		n.set_all_icons();
		tree.redraw();
		added.removeElement(n);
		}
	}

	static String urlize(String s)
	{
	StringBuffer rv = new StringBuffer();
	for(int i=0; i<s.length(); i++) {
		char c = s.charAt(i);
		if (c < 16)
			rv.append("%0"+Integer.toString(c, 16));
		else if (!Character.isLetterOrDigit(c) && c != '/' &&
		    c != '.' && c != '_' && c != '-')
			rv.append("%"+Integer.toString(c, 16));
		else
			rv.append(c);
		}
	return rv.toString();
	}
}

class BaculaNode extends HierarchyNode
{
	TreeChooser parent;
	String path;
	boolean isdir;
	boolean known = false;
	boolean added = false;
	BaculaNode dir;

	BaculaNode(TreeChooser parent, String path, boolean isdir, BaculaNode dir)
	{
	this.parent = parent;
	this.path = path;
	this.isdir = isdir;
	this.dir = dir;
	open = false;
	set_icon();
	ch = isdir ? new Vector() : null;
	if (path.equals("/"))
		text = "/";
	else {
		String ns = path.endsWith("/") ?
				path.substring(0, path.length() - 1) : path;
		int slash = ns.lastIndexOf("/");
		text = path.substring(slash+1);
		}
	}

	void set_icon()
	{
	String imname = isdir ? "dir.gif" : "rfile.gif";
	if (selected()) imname = "s"+imname;
	im = parent.get_image(imname);
	}

	void set_all_icons()
	{
	set_icon();
	if (ch != null) {
		for(int i=0; i<ch.size(); i++) {
			BaculaNode c = (BaculaNode)ch.elementAt(i);
			c.set_all_icons();
			}
		}
	}

	void fill()
	{
	if (!known && isdir) {
		ch.removeAllElements();
		String l[] = parent.get_text("list.cgi?dir="+
					     parent.urlize(path)+
					     "&volume="+
					     parent.urlize(parent.volume)+
					     "&job="+
					     parent.urlize(parent.job));
		if (l[0].length() > 0) {
			new ErrorWindow("Failed to get files under "+path+
					" : "+l[0]);
			return;
			}
		for(int i=1; i<l.length; i++) {
			if (l[i].endsWith("/")) {
				ch.addElement(
				    new BaculaNode(
					    parent, l[i].substring(0, l[i].length()-1),
					    true, this));
				}
			else {
				ch.addElement(
				    new BaculaNode(
				    	parent, l[i], false, this));
				}
			}
		parent.tree.redraw();
		known = true;
		}
	}

	boolean selected()
	{
	BaculaNode n = this;
	while(n != null) {
		if (n.added) return true;
		n = n.dir;
		}
	return false;
	}
}

