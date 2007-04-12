import java.awt.*; 

class CbSlider extends Canvas
{
	int dir, min, max, pos;
	CbSliderCallback callback;
	int px, py;
	Color lc1 = Util.light_edge, lc2 = Util.body, lc3 = Util.dark_edge;
	Color hc1 = Util.light_edge_hi, hc2 = Util.body_hi, hc3 = Util.dark_edge_hi;
	int ticks = 0;
	boolean inside = false, dragging = false;
	int dragx;

	/**Create a new slider
	 * @param d		0=horizontal, 1=vertical
	 * @param mi	Minimum value
	 * @param ma	Maximum value
	 * @param p		Current value
	 */
	public CbSlider(int d, int mi, int ma, int p)
	{
	this(d, mi, ma, p, null);
	}

	/**Create a new slider
	 * @param d		0=horizontal, 1=vertical
	 * @param mi	Minimum value
	 * @param ma	Maximum value
	 * @param p		Current value
	 * @param cb	Object to call back to
	 */
	public CbSlider(int d, int mi, int ma, int p, CbSliderCallback cb)
	{
	dir = d; min = mi; max = ma;
	pos = p;
	callback = cb;
	}

	/**Toggle drawing of tick-marks on the slider track
	 * @param t		The number of units/tick, or 0 to disable
	 */
	public void setTicks(int t)
	{
	ticks = t;
	repaint();
	}

	/**Returns the current slider position
	 */
	public int getPosition() { return pos; }

	/**Sets the current slider position
	 */
	public void setPosition(int p)
	{
	if (pos != p) {
		pos = p;
		repaint();
		}
	}

	/**Returns the current minimum slider value
	 */
	public int getMinimum() { return min; }

	/**Sets the minimum slider value
	 * @param mi	The new minimum
	 */
	public void setMinimum(int mi)
	{
	min = mi;
	checkPos();
	repaint();
	}

	/**Returns the current maximum slider value
	 */
	public int getMaximum() { return max; }

	/**Sets the maximum slider value
	 * @param mx	The new maximum
	 */
	public void setMaximum(int mx)
	{
	max = mx;
	checkPos();
	repaint();
	}

	public void paint(Graphics g)
	{
	Color c1 = inside ? hc1 : lc1,
	      c2 = inside ? hc2 : lc2,
	      c3 = inside ? hc3 : lc3;

	// draw slider track
	int w = size().width, h = size().height;
	g.setColor(c2);
	g.fillRect(0, 0, w, h);
	g.setColor(c3);
	g.drawLine(8, h/2, w-8, h/2);
	g.setColor(c1);
	g.drawLine(8, h/2+1, w-8, h/2+1);

	// draw border
	g.setColor(c1);
	g.drawLine(0, 0, w-1, 0);
	g.drawLine(0, 0, 0, h-1);
	g.setColor(c3);
	g.drawLine(w-1, h-1, w-1, 0);
	g.drawLine(w-1, h-1, 0, h-1);
	if (inside) {
		g.drawLine(w-2, h-2, w-2, 0);
		g.drawLine(w-2, h-2, 0, h-2);
		}

	// draw tick marks
	if (ticks != 0) {
		int mm = max-min;
		for(int i=0; i<=mm; i+=ticks) {
			int tx = ((w-16)*i / mm) + 8;
			g.setColor(c3);
			g.drawLine(tx, h/2, tx, h/2-6);
			}
		}

	// draw slider
	px = ((w-16)*pos / (max - min)) + 8;
	py = h/2;
	g.setColor(c2);
	int xpt[] = { px-3, px-3, px, px+3, px+3 };
	int ypt[] = { py+5, py-4, py-6, py-4, py+5 };
	g.fillPolygon(xpt, ypt, 5);
	g.setColor(dragging ? c3 : c1);
	g.drawLine(px-3, py+5, px-3, py-4);
	g.drawLine(px-3, py-4, px, py-6);
	g.setColor(dragging ? c1 : c3);
	g.drawLine(px-3, py+5, px+3, py+5);
	g.drawLine(px+3, py+5, px+3, py-4);
	}

	public void update(Graphics g) { paint(g); }

	public boolean mouseEnter(Event e, int x, int y)
	{
	inside = true;
	repaint();
	return true;
	}

	public boolean mouseDown(Event e, int x, int y)
	{
	int step = ticks==0 ? (max-min)/10 : ticks;
	if (x < px-3) {
		// move one tick to the left
		pos -= step;
		}
	else if (x > px+3) {
		// move one tick to the right
		pos += step;
		}
	else {
		// start dragging
		dragging = true;
		dragx = x-px;
		}
	checkPos();
	if (callback != null)
		callback.moved(this, pos);
	repaint();
	return true;
	}

	public boolean mouseDrag(Event e, int x, int y)
	{
	if (dragging) {
		px = x-dragx;
		pos = (px-8)*(max - min) / (size().width-16);
		checkPos();
		if (callback != null)
			callback.moving(this, pos);
		repaint();
		}
	return dragging;
	}

	public boolean mouseUp(Event e, int x, int y)
	{
	if (dragging) {
		dragging = false;
		if (callback != null)
			callback.moved(this, pos);
		repaint();
		return true;
		}
	return false;
	}

	public boolean mouseExit(Event e, int x, int y)
	{
	inside = false;
	repaint();
	return true;
	}

	protected void checkPos()
	{
	if (pos < min) pos = min;
	else if (pos > max) pos = max;
	}

	public Dimension preferredSize()
	{
	return new Dimension(100, 20);
	}

	public Dimension minimumSize() { return preferredSize(); }
}

interface CbSliderCallback
{
	/**Callled back when the slider stops at a new position
	 * @param s		The slider being moved
	 * @param p		New position
	 */
	public void moved(CbSlider s, int p);

	/**Callled back whenever the slider is being dragged
	 * @param s		The slider being moved
	 * @param p		New position
	 */
	public void moving(CbSlider s, int p);
}
