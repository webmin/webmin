import java.awt.*;

class BorderPanel extends Panel
{
	int border = 5;	// size of border
	Color col1 = Util.light_edge;
	Color col2 = Util.dark_edge;
	Color body;

	BorderPanel()
	{
	}

	BorderPanel(int w)
	{
	border = w;
	}

	BorderPanel(int w, Color cb)
	{
	border = w;
	body = cb;
	}

	BorderPanel(int w, Color c1, Color c2)
	{	
	border = w;
	col1 = c1; col2 = c2;
	}

	BorderPanel(int w, Color c1, Color c2, Color cb)
	{
	border = w;
	col1 = c1; col2 = c2; body = cb;
	}

	BorderPanel(Color c1, Color c2)
	{
	col1 = c1; col2 = c2;
	}

	public Insets insets()
	{
	return new Insets(border+2, border+2, border+2, border+2);
	}

	public void paint(Graphics g)
	{
	if (body != null) {
		g.setColor(body);
		g.fillRect(0, 0, size().width, size().height);
		}
	super.paint(g);
	int w = size().width-1, h = size().height-1;
	g.setColor(col1);
	for(int i=0; i<border; i++) {
		g.drawLine(i,i,w-i,i);
		g.drawLine(i,i,i,h-i);
		}
	g.setColor(col2);
	for(int i=0; i<border; i++) {
		g.drawLine(w-i,h-i, w-i,i);
		g.drawLine(w-i,h-i, i,h-i);
		}
	}
}

