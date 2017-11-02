// ResizePanel
// A panel with two parts, arranged either vertically or horizontally,
// whose midpoint is adjustable
import java.awt.*;
import java.util.Vector;

public class ResizePanel extends Panel implements LayoutManager
{
	Component one, two;
	int pos = -1;
	double ratio;
	boolean vertical;
	boolean dragging;
	int border = 100;

	// Provide two components where component one initially occupies rt fraction of
	// parent area. When vertical=true components are laid out one above the other
	public ResizePanel(Component one, Component two, double rt, boolean vertical)
	{
		this.one = one;
		this.two = two;
		this.vertical = vertical;
		ratio = rt;
		setLayout(this);
		add(one);
		add(two);
	}

	public void paint(Graphics g)
	{
		Dimension s = size();
		if (vertical)
		{
			// Draw horizontal bar between vertically aligned components
			pos = (int)(s.height * ratio);
			g.setColor(Color.white);
			g.drawLine(0, pos-2, 0, pos+1);
			g.drawLine(0, pos-2, s.width-2, pos-2);
			g.setColor(Color.black);
			g.drawLine(s.width-1, pos+2, s.width-1, pos-1);
			g.drawLine(s.width-1, pos+2, 1, pos+2);
		}
		else
		{
			// Draw vertical divider bar
			pos = (int)(s.width * ratio);
			g.setColor(Color.white);
			g.drawLine(pos-2, 0, pos+1, 0);
			g.drawLine(pos-2, 0, pos-2, s.height-2);
			g.setColor(Color.black);
			g.drawLine(pos+2, s.height-1, pos-1, s.height-1);
			g.drawLine(pos+2, s.height-1, pos+2, 1);
		}
	}

	// Detect mouse click on divider bar
	public boolean mouseDown(Event evt, int x, int y)
	{
		int sh;
		Dimension s = size();
		if (vertical && y >= pos-2 && y <= pos+2)
		{
			// Started dragging
			dragging = true;
		}
		if (!vertical && x >= pos-2 && x <= pos+2)
		{
			// Started dragging
			dragging = true;
		}
		return dragging;
	}

	// Move division point on mouse drag
	public boolean mouseDrag(Event evt, int x, int y)
	{
		if (dragging)
		{
			Dimension s = size();
			if (vertical)
			{
				if (y < border)
					pos = border;
				else if (y > s.height - border)
					pos = s.height - border;
				else
					pos = y;
				ratio = (double)pos / (double)s.height;
			}
			else
			{
				if (x < border)
					pos = border;
				else if (x > s.width - border)
					pos = s.width - border;
				else
					pos = x;
				ratio = (double)pos / (double)s.width;
			}
			layoutContainer(this);
			repaint();
		}
		return dragging;
	}

	// No longer dragging on mouse button release
	public boolean mouseUp(Event evt, int x, int y)
	{
		boolean o = dragging;
		dragging = false;
		return o;
	}

	public void addLayoutComponent(String name, Component comp)
	{
	}

	// Arrange components within container
	public void layoutContainer(Container parent)
	{
		Dimension s = parent.size();
		if (vertical)
		{
			pos = (int)(s.height * ratio);
			one.reshape(0, 0, s.width, pos-3);
			one.layout();
			two.reshape(0, pos+3, s.width, s.height - pos - 5);
			two.layout();
		}
		else
		{
			pos = (int)(s.width * ratio);
			one.reshape(0, 0, pos-3, s.height);
			one.layout();
			two.reshape(pos+3, 0, s.width - pos - 5, s.height);
			two.layout();
		}
	}

	// Determine minimum size for ResizePanel
	public Dimension minimumLayoutSize(Container parent)
	{
		Dimension d1 = one.minimumSize(),
		          d2 = two.minimumSize();

		if (vertical)
		{
			// Largest of the widths, sum of the heights
			return new Dimension(d1.width > d2.width ? d1.width : d2.width,
			                     d1.height + d2.height);
		}
		else
		{
			// Largest of the heights, sum of the widths
			return new Dimension(d1.width + d2.width,
			                     d1.height > d2.height ? d1.height : d2.height);
		}
	}

	public Dimension preferredLayoutSize(Container parent)
	{
		return minimumLayoutSize(parent);
	}

	public void removeLayoutComponent(Component comp)
	{
	}
}

