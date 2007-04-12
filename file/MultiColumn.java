// MultiColumn
// A List box that supports multiple columns.
import java.awt.*;
import java.util.Vector;

public class MultiColumn extends BorderPanel implements CbScrollbarCallback
{
	MultiColumnCallback callback;	// what to call back to 
	String title[];			// column titles
	boolean adjustable = true;
	boolean drawlines = true;
	Color colors[][] = null;
	boolean enabled = true;
	boolean multiselect = false;
	int cpos[];			// column x positions
	float cwidth[];			// proportional column widths
	Vector list[];			// columns of the list
	CbScrollbar sb;			// scrollbar at the right side
	int width, height;		// size, minus the scrollbar
	Insets in;			// used space around the border
	int sbwidth;			// width of the scrollbar
	int th;				// height of title bar
	Image bim;			// backing image
	Graphics bg;			// backing graphics
	Font font = new Font("timesRoman", Font.PLAIN, 12);
	FontMetrics fnm;		// drawing font size
	int coldrag = -1;		// column being resized
	int sel = -1;			// selected row
	int sels[] = new int[0];	// all selected rows
	int top = 0;			// first row displayed
	long last;			// last mouse click time
	int rowh = 16;			// row height
	Event last_event;		// last event that triggered callback
	int sortcol;			// Column currently being sorted
	int sortdir;			// Sort direction (0=none, 1=up, 2=down)

	// Create a new list with the given column titles
	MultiColumn(String t[])
	{
	super(3, Util.dark_edge_hi, Util.body_hi);
	title = new String[t.length];
	for(int i=0; i<t.length; i++)
		title[i] = t[i];
	list = new Vector[t.length];
	for(int i=0; i<t.length; i++)
		list[i] = new Vector();
	cwidth = new float[t.length];
	for(int i=0; i<t.length; i++)
		cwidth[i] = 1.0f/t.length;
	cpos = new int[t.length+1];
	setLayout(null);
	sb = new CbScrollbar(CbScrollbar.VERTICAL, this);
	add(sb);
	}

	// Create a new list that calls back to the given object on
	// single or double clicks.
	MultiColumn(String t[], MultiColumnCallback c)
	{
	this(t);
	callback = c;
	}

	// addItem
	// Add a row to the list
	void addItem(Object item[])
	{
	for(int i=0; i<title.length; i++)
		list[i].addElement(item[i]);
	repaint();
	compscroll();
	}

	// addItems
	// Add several rows to the list
	void addItems(Object item[][])
	{
	for(int i=0; i<item.length; i++)
		for(int j=0; j<title.length; j++)
			list[j].addElement(item[i][j]);
	repaint();
	compscroll();
	}

	// modifyItem
	// Changes one row of the table
	void modifyItem(Object item[], int row)
	{
	for(int i=0; i<title.length; i++)
		list[i].setElementAt(item[i], row);
	repaint();
	compscroll();
	}

	// getItem
	// Returns the contents of a given row
	Object []getItem(int n)
	{
	Object r[] = new Object[title.length];
	for(int i=0; i<title.length; i++)
		r[i] = list[i].elementAt(n);
	return r;
	}

	// selected
	// Return the most recently selected row
	int selected()
	{
	return sel;
	}

	// select
	// Select some row
	void select(int s)
	{
	sel = s;
	sels = new int[1];
	sels[0] = s;
	repaint();
	}

	// select
	// Select multiple rows
	void select(int s[])
	{
	if (s.length == 0) {
		sel = -1;
		sels = new int[0];
		}
	else {
		sel = s[0];
		sels = s;
		}
	repaint();
	}

	// allSelected
	// Returns all the selected rows
	int[] allSelected()
	{
	return sels;
	}

	// scrollto
	// Scroll to make some row visible
	void scrollto(int s)
	{
	int r = rows();
	if (s < top || s >= top+r) {
		top = s-1;
		if (top > list[0].size() - r)
			top = list[0].size() - r;
		sb.setValue(top);
		repaint();
		}
	}

	// deleteItem
	// Remove one row from the list
	void deleteItem(int n)
	{
	for(int i=0; i<title.length; i++)
		list[i].removeElementAt(n);
	if (n == sel) {
		// De-select deleted file
		sel = -1;
		}
	for(int i=0; i<sels.length; i++) {
		if (sels[i] == n) {
			// Remove from selection list
			int nsels[] = new int[sels.length-1];
			if (nsels.length > 0) {
				System.arraycopy(sels, 0, nsels, 0, i);
				System.arraycopy(sels, i+1, nsels, i,
						 nsels.length-i);
				sel = nsels[0];
				}
			break;
			}
		}
	repaint();
	compscroll();
	}

	// clear
	// Remove everything from the list
	void clear()
	{
	for(int i=0; i<title.length; i++)
		list[i].removeAllElements();
	sel = -1;
	sels = new int[0];
	top = 0;
	repaint();
	sb.setValues(0, 1, 0);
	}

	// setWidths
	// Set the proportional widths of each column
	void setWidths(float w[])
	{
	for(int i=0; i<title.length; i++)
		cwidth[i] = w[i];
	respace();
	repaint();
	}

	/**Turns on or off the user's ability to adjust column widths
	 * @param a	Can adjust or not?
	 */
	void setAdjustable(boolean a)
	{
	adjustable = a;
	}

	/**Turns on or off the drawing of column lines
	 * @param d	Draw lines or not?
	 */
	void setDrawLines(boolean d)
	{
	drawlines = d;
	}

	/**Sets the array of colors used to draw text items.
	 * @param c	The color array (in row/column order), or null to
	 *		use the default
	 */
	void setColors(Color c[][])
	{
	colors = c;
	repaint();
	}

	// Turns on or off multi-row selection with ctrl and shift
	void setMultiSelect(boolean m)
	{
	multiselect = m;
	}

	// Enables the entire list
	public void enable()
	{
	enabled = true;
	sb.enable();
	repaint();
	}

	// Disables the entire list
	public void disable()
	{
	enabled = false;
	sb.disable();
	repaint();
	}

	// Sets or turns off the sort indication arrow for a column
	// Direction 0 = None, 1 = Up arrow, 2 = Down arrow
	public void sortingArrow(int col, int dir)
	{
	sortcol = col;
	sortdir = dir;
	repaint();
	}

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
	if (nw != width+sbwidth || nh != height) {
		in = insets();
		sbwidth = sb.minimumSize().width;
		width = nw-sbwidth - (in.left + in.right);
		height = nh - (in.top + in.bottom);
		sb.reshape(width+in.left, in.top, sbwidth, height);
		respace();

		// Force creation of a new backing image and re-painting
		bim = null;
		repaint();
		compscroll();
		}
	super.reshape(nx, ny, nw, nh);
	}

	// respace
	// Compute pixel column widths from proportional widths
	void respace()
	{
	cpos[0] = 0;
	for(int i=0; i<title.length; i++)
		cpos[i+1] = cpos[i] + (int)(width*cwidth[i]);
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
		th = fnm.getHeight() + 4;
		render();
		compscroll();
		}
	g.drawImage(bim, in.left, in.top, this);
	}

	// update
	// Called sometime after repaint()
	public void update(Graphics g)
	{
	if (fnm != null) {
		render();
		paint(g);
		}
	}

	// render
	// Re-draw the list into the backing image
	void render()
	{
	int fh = fnm.getHeight(),	// useful font metrics
	    fd = fnm.getDescent(),
	    fa = fnm.getAscent();
	int bot = Math.min(top+rows()-1, list[0].size()-1);

	// Clear title section and list
	bg.setColor(Util.body);
	bg.fillRect(0, 0, width, th);
	bg.setColor(Util.light_bg);
	bg.fillRect(0, th, width, height-th);
	Color lighterGray = Util.body_hi;

	if (enabled) {
		// Mark the selected rows
		for(int i=0; i<sels.length; i++) {
			if (sels[i] >= top && sels[i] <= bot) {
				bg.setColor(sels[i] == sel ? Util.body
							   : lighterGray);
				bg.fillRect(0, th+(sels[i]-top)*rowh,
					    width, rowh);
				}
			}
		}

	// Draw each column
	for(int i=0; i<title.length; i++) {
		int x = cpos[i], w = cpos[i+1]-x-1;

		// Column title
		bg.setColor(Util.light_edge);
		bg.drawLine(x, 0, x+w, 0);
		bg.drawLine(x, 1, x+w-1, 1);
		bg.drawLine(x, 0, x, th-1);
		bg.drawLine(x+1, 0, x+1, th-2);
		bg.setColor(Util.dark_edge);
		bg.drawLine(x, th-1, x+w, th-1);
		bg.drawLine(x, th-2, x+w-1, th-2);
		bg.drawLine(x+w, th-1, x+w, 0);
		bg.drawLine(x+w-1, th-1, x+w-1, 1);
		int tw = fnm.stringWidth(title[i]);
		if (tw < w-6)
			bg.drawString(title[i], x+(w-tw)/2, th-fd-2);

		// Sorting arrow
		int as = th-8;
		if (sortcol == i && sortdir == 1) {
			bg.setColor(Util.light_edge);
			bg.drawLine(x+4, th-5, x+4+as, th-5);
			bg.drawLine(x+4+as, th-5, x+4+as/2, th-5-as);
			bg.setColor(Util.dark_edge);
			bg.drawLine(x+4+as/2, th-5-as, x+4, th-5);
			}
		else if (sortcol == i && sortdir == 2) {
			bg.setColor(Util.light_edge);
			bg.drawLine(x+4+as/2, th-5, x+4+as, th-5-as);
			bg.setColor(Util.dark_edge);
			bg.drawLine(x+4, th-5-as, x+4+as, th-5-as);
			bg.drawLine(x+4, th-5-as, x+4+as/2, th-5);
			}

		// Column items
		if (drawlines) {
			bg.setColor(Util.body);
			bg.drawLine(x+w-1, th, x+w-1, height);
			bg.setColor(Util.dark_edge);
			bg.drawLine(x+w, th, x+w, height);
			}
		for(int j=top; j<=bot; j++) {
			Object o = list[i].elementAt(j);
			if (o instanceof String) {
				// Render string in column
				String s = (String)o;
				while(fnm.stringWidth(s) > w-3)
					s = s.substring(0, s.length()-1);
				if (!enabled)
					bg.setColor(Util.body);
				else if (colors != null)
					bg.setColor(colors[j][i]);
				bg.drawString(s, x+1, th+(j+1-top)*rowh-fd);
				}
			else if (o instanceof Image) {
				// Render image in column
				Image im = (Image)o;
				bg.drawImage(im, x+1, th+(j-top)*rowh, this);
				}
			}
		}
	}

	// mouseDown
	// Select a list item or a column to drag
	public boolean mouseDown(Event e, int x, int y)
	{
	if (!enabled) {
		return true;
		}
	x -= in.left;
	y -= in.top;
	coldrag = -1;
	if (y < th) {
		// Click in title bar
		for(int i=0; i<title.length; i++) {
			if (adjustable && i > 0 && Math.abs(cpos[i] - x) < 3) {
				// clicked on a column separator
				coldrag = i;
				}
			else if (x >= cpos[i] && x < cpos[i+1]) {
				// clicked in a title
				callback.headingClicked(this, i);
				}
			}
		}
	else {
		// Item chosen from list
		int row = (y-th)/rowh + top;
		if (row < list[0].size()) {
			// Double-click?
			boolean dclick = false;
			if (e.when-last < 1000 && sel == row)
				dclick = true;
			else
				last = e.when;

			if (e.shiftDown() && multiselect && sel != -1) {
				// Select all from last selection to this one
				int zero = sels[0];
				if (zero < row) {
					sels = new int[row-zero+1];
					for(int i=zero; i<=row; i++)
						sels[i-zero] = i;
					}
				else {
					sels = new int[zero-row+1];
					for(int i=zero; i>=row; i--)
						sels[zero-i] = i;
					}
				}
			else if (e.controlDown() && multiselect) {
				// Add this one to selection
				int nsels[] = new int[sels.length + 1];
				System.arraycopy(sels, 0, nsels, 0,sels.length);
				nsels[sels.length] = row;
				sels = nsels;
				}
			else {
				// Select one row only, and de-select others
				sels = new int[1];
				sels[0] = row;
				}
			sel = row;
			repaint();
			last_event = e;
			if (callback != null) {
				// Callback the right function
				if (dclick) callback.doubleClick(this, row);
				else	    callback.singleClick(this, row);
				}
			else {
				// Send an event
				getParent().postEvent(
					new Event(this,
						  Event.ACTION_EVENT,
						  dclick?"Double":"Single"));
				}
			}
		}
	return true;
	}

	// mouseDrag
	// If a column is selected, change it's width
	public boolean mouseDrag(Event e, int x, int y)
	{
	if (!enabled) {
		return true;
		}
	x -= in.left;
	y -= in.top;
	if (coldrag != -1) {
		if (x > cpos[coldrag-1]+3 && x < cpos[coldrag+1]-3) {
			cpos[coldrag] = x;
			cwidth[coldrag-1] = (cpos[coldrag]-cpos[coldrag-1]) /
					    (float)width;
			cwidth[coldrag] = (cpos[coldrag+1]-cpos[coldrag]) /
					    (float)width;
			repaint();
			}
		}
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

	// compscroll
	// Re-compute the size of the scrollbar
	private void compscroll()
	{
	if (fnm == null)
		return;		// not visible
	int r = rows();
	int c = list[0].size() - r;
	sb.setValues(top, r==0?1:r, list[0].size());
	}

	// rows
	// Returns the number of rows visible in the list
	private int rows()
	{
	return Math.min(height/rowh - 1, list[0].size());
	}

	public Dimension minimumSize()
	{
	return new Dimension(400, 100);
	}

	public Dimension preferredSize()
	{
	return minimumSize();
	}
}

// MultiColumnCallback
// Objects implementing this interface can be passed to the MultiColumn
// class, to have their singleClick() and doubleClick() functions called in
// response to single or double click in the list.
interface MultiColumnCallback
{
	// singleClick
	// Called on a single click on a list item
	void singleClick(MultiColumn list, int num);

	// doubleClick
	// Called upon double-clicking on a list item
	void doubleClick(MultiColumn list, int num);

	// headingClicked
	// Called when a column heading is clicked on
	void headingClicked(MultiColumn list, int col);
}

