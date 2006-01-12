#include <QApplication>
#include <QLabel>
#include <QVBoxLayout>
#include <QShortcut>
#include <QPushButton>
#include <QMainWindow>

#include <QAbstractItemView>
#include <QAbstractSlider>

struct CursorAction : public QAbstractItemView {
	operator QAbstractItemView::CursorAction () { return (QAbstractItemView::CursorAction)0; };
};

struct SliderChange : public QAbstractSlider {
	operator QAbstractSlider::SliderChange () { return (QAbstractSlider::SliderChange)0; };
};


class ASlot : public QObject {

	Q_OBJECT;

signals:
	void somebody_set_up_us_the_bomb();

public slots:

	void destroyed(QObject* obj) {

		printf("destroy them !!\n");
	};
	void activated() {

		printf("activensen !!\n");
	};
	int return_slot(double a) {return (int)a;};
public:
	void a_method() {};
	int another_method(SliderChange* p_ch) { return int();};

};

class Virtuals {

protected:
	void closeEvent(QCloseEvent* e) {

		printf("******* close event on Virtuals\n");
	};
};

class Window : public QMainWindow , public Virtuals {

};

#include "test.moc"

int main(int argc, char *argv[])
{
	QApplication app(argc, argv);
	Window* win = new Window();
	QWidget* w = new QWidget(win);
	QVBoxLayout* box = new QVBoxLayout(w);
	//w->setLayout(box);
	QLabel* label = new QLabel(w);
	label->setText("hello");
	QLabel* label2 = new QLabel("label 2", w);
	box->addWidget(label);
	box->addWidget(label2);

	ASlot* aslot = new ASlot();

	QPushButton* but = new QPushButton("destry me", w);
	box->addWidget(but);
	QObject::connect(but, SIGNAL(clicked()), but, SLOT(deleteLater()));
	QObject::connect(but, SIGNAL(destroyed(QObject*)), aslot, SLOT(destroyed(QObject*)));

	QObject::connect(w, SIGNAL(destroyed(QObject*)), aslot, SLOT(destroyed(QObject*)));

	QShortcut* sc = new QShortcut(w);
	sc->setKey(Qt::Key_Return);
	QObject::connect(sc, SIGNAL(activated()), aslot, SLOT(activated()));

	win->show();
	return app.exec();
}

