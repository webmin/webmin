import java.awt.*;

// StaticTextField
// A text field that is set to be non-editable by default
class StaticTextField extends TextField
{
	StaticTextField()
	{
	super();
	setEditable(false);
	}

	StaticTextField(String s)
	{
	super(s);
	setEditable(false);
	}

	StaticTextField(String s, int i)
	{
	super(s,i);
	setEditable(false);
	}
}
