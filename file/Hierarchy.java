// Hierarchy
// An AWT component for displaying a tree-like heirachy, with each node
// having an icon and a name. This heirachy can be expanded or contracted
// by the user.
import java.awt.*;
import java.util.Vector;

public class Hierarchy extends BorderPanel implements CbScrollbarCallback
{
	HierarchyNode root;		// the root of the tree
	CbScrollbar sb;			// scrollbar at right
	int width, height;		// usable drawing area
	int sbwidth;			// size of scrollbar
	HierarchyCallback callback;	// who to call on open / close
	Image bim;			// double-buffer image
	Font font = new Font("courier", Font.PLAIN, 12);
	FontMetrics fnm;		// size of font used
	Graphics bg;			// back-images graphics
	int top = 0;			// top-most row displayed
	int count = 0;			// total rows in the tree
	Insets in;			// insets from border
	HierarchyNode sel;		// selected node
	long last;			// time of last mouse click
	static boolean broken_awt = System.getProperty("os.name").
				    startsWith("Windows");

	// Create a new Hierarchy object with the given root
	Hierarchy(HierarchyNode r)
	{
	this();
	root = r;
	}

	// Create a new Hierarchy object that calls back to the given object
	// when nodes are clicked on.
	Hierarchy(HierarchyNode r, HierarchyCallback c)
	{
	this(r);
	callback = c;
	}

	// Create an empty hierarchy object, with no callback
	Hierarchy()
	{
	super(3, Util.dark_edge_hi, Util.body_hi);

	// Create UI
	setLayout(null);
	sb = new CbScrollbar(CbScrollbar.VERTICAL, this);
	add(sb);
	}

	// Create an empty hierarchy object, set to report user actions to
	// the given object.
	Hierarchy(HierarchyCallback c)
	{
	this();
	callback = c;
	}

	// redraw
	// Called by the using class when the tree passed to this object
	// changes, to force a redraw and resizing of the scrollbar
	void redraw()
	{
	if (fnm != null) {
		render();
		paint(getGraphics());
		compscroll();
		}
	}

	// setRoot
	// Set the root node for this hierarchy
	void setRoot(HierarchyNode r)
	{
	root = r;
	redraw();
	}

	// selected
	// Return the currently selected node, or null
	HierarchyNode selected()
	{
	return sel;
	}

	// select
	// Selected the given node
	void select(HierarchyNode s)
	{
	sel = s;
	}

	// force the use of some font
	public void setFont(Font f)
	{
	font = f;
	bim = null;
	repaint();
	}

	// reshape
	// Called when this component gets resized
	public void reshape(int nx, int ny, int nw, int nh)
	{
	in = insets();
	sbwidth = sb.minimumSize().width;
	width = nw-sbwidth - (in.left + in.right);
	height = nh - (in.top + in.bottom);
	sb.reshape(width+in.left, in.top, sbwidth, height);

	// force creation of a new backing images
	bim = null;
	repaint();
	compscroll();

	super.reshape(nx, ny, nw, nh);
	}

	// update
	// Called sometime after repaint()
	public void update(Graphics g)
	{
	render();
	paint(g);
	}

	// paint
	// Blit the backing image to the front
	public void paint(Graphics g)
	{
	super.paint(g);
	if (bim == null) {
		// This is the first rendering
		bim = createImage(width, height);
		bg = bim.getGraphics();
		bg.setFont(font);
		fnm = bg.getFontMetrics();
		render();
		compscroll();
		}
	g.drawImage(bim, in.left, in.top, this);
	}

	// mouseDown
	// Called upon a mouseclick
	public boolean mouseDown(Event evt, int x, int y)
	{
	if (root == null)
		return false;		// nothing to do
	HierarchyNode s = nodeat(root, x/16, (y/16)+top);
	if (s == null) {
		// Just deselect
		sel = null;
		repaint();
		return true;
		}

	// Check for double-click
	boolean dc = false;
	if (evt.when-last < 500 && sel == s)
		dc = true;
	else
		last = evt.when;
	sel = s;

	if (dc && sel.ch != null) {
		// Open or close this node
		sel.open = !sel.open;
		if (callback != null) {
			// Notify callback, which MAY do something to change
			// the structure of the tree
			if (sel.open) callback.openNode(this, sel);
			else	      callback.closeNode(this, sel);
			}
		}
	else if (callback != null) {
		// Single click on a node or double-click on leaf node
		if (dc) callback.doubleNode(this, sel);
		else    callback.clickNode(this, sel);
		}
	compscroll();
	repaint();
	return true;
	}

	public void moved(CbScrollbar s, int v)
	{
	moving(s, v);
	}

	public void moving(CbScrollbar s, int v)
	{
	top = sb.getValue();
	compscroll();
	repaint();
	}

	// render
	// Draw the current tree view into the backing image
	private void render()
	{
	if (fnm != null) {
		int fh = fnm.getHeight(),	// useful font metrics
		    fa = fnm.getAscent();
		bg.setColor(Util.light_bg);
		bg.fillRect(0, 0, width, height);
		if (root == null)
			return;		// nothing to do
		bg.setColor(Util.text);
		recurse(root, 0, 0, fh, fa);
		}
	}

	// recurse
	// Render a node in the tree at the given location, maybe followed
	// by all it's children. Return the number of rows this node took
	// to display.
	private int recurse(HierarchyNode n, int x, int y, int fh, int fa)
	{
	int xx = x*16, yy = (y-top)*16;
	int len = 1;

	n.x = x;
	n.y = y;
	int tw = fnm.stringWidth(n.text);
	if (yy >= 0 && yy <= height) {
		// Draw this node
		if (n.im != null)
			bg.drawImage(n.im, xx, yy, this);
		if (sel == n) {
			// Select this node
			bg.setColor(Util.body);
			bg.fillRect(xx+17, yy+2, tw+2, 13);
			bg.setColor(Util.text);
			}
		bg.drawString(n.text, xx+18, yy+12);
		}
	if (n.ch != null && n.open && yy <= height) {
		// Mark this node
		bg.drawLine(xx+18, yy+14, xx+17+tw, yy+14);

		// Draw subnodes
		yy += 16;
		for(int i=0; i<n.ch.size() && yy<=height; i++) {
			int l=recurse((HierarchyNode)n.ch.elementAt(i),
				      x+1, y+len, fh, fa);
			bg.drawLine(xx+7, yy+7, xx+15, yy+7);
			if (i == n.ch.size()-1)
				bg.drawLine(xx+7, yy, xx+7, yy+7);
			else
				bg.drawLine(xx+7, yy, xx+7,yy+(l*16)-1);
			len += l;
			yy += l*16;
			}
		}
	return len;
	}

	// compscroll
	// Re-compute scrollbar size
	private void compscroll()
	{
	if (fnm == null)
		return;
	int ct = root!=null ? count(root) : 1;
	int r = Math.min(ct, height/16 - 1);
	int c = ct - r;
	//sb.setValues(top, r==0?1:r, c<0?0:c);
	sb.setValues(top, r==0?1:r, ct);
	}

	// count
	// Returns the number of visible rows from a node
	private int count(HierarchyNode n)
	{
	int l = 1;
	if (n.open && n.ch != null)
		for(int i=0; i<n.ch.size(); i++)
			l += count((HierarchyNode)n.ch.elementAt(i));
	return l;
	}

	// nodeat
	// Is the given node at the given position? If not, check its
	// children too.
	private HierarchyNode nodeat(HierarchyNode n, int x, int y)
	{
	if (y == n.y && x >= n.x)
		return n;
	if (n.ch == null || !n.open)
		return null;
	for(int i=0; i<n.ch.size(); i++) {
		HierarchyNode c = nodeat((HierarchyNode)n.ch.elementAt(i),x,y);
		if (c != null) return c;
		}
	return null;
	}
}

// HierarchyNode
// One node in the tree displayed by the Hierarchy object.
class HierarchyNode
{
	boolean open;		// is this node open?
	Image im;		// icon for this node (assumed to be 16x16!)
	Vector ch;		// sub-nodes of this one, or null
	String text;		// name of this node
	int x, y;		// row/column in list

	HierarchyNode() { }

	HierarchyNode(boolean o, Image i, Vector c, String t)
	{
	open = o;
	im = i;
	ch = c;
	text = t;
	}
}

// HierarchyCallback
// Programmers using the Hierarchy class pass an object that implements the
// HierarchyCallback interface to its constructor, to receive information
// about user actions.
interface HierarchyCallback
{
	// openNode
	// Called when a node with children is opened
	void openNode(Hierarchy h, HierarchyNode n);

	// closeNode
	// Called when a node is closed
	void closeNode(Hierarchy h, HierarchyNode n);

	// clickNode
	// Called when the user clicks on a node
	void clickNode(Hierarchy h, HierarchyNode n);

	// doubleNode
	// Called when a user double-clicks on a node
	void doubleNode(Hierarchy h, HierarchyNode n);
}

