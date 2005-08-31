#include <QApplication>
#include <QLabel>
#include <QVBoxLayout>
#include <QShortcut>

class ASlot : public QObject {

	Q_OBJECT;

public slots:

	void destroyed(QObject* obj) {

		printf("destroy them !!\n");
	};
	void activated() {

		printf("activensen !!\n");
	};

};

#include "test.moc"

int main(int argc, char *argv[])
{
	QApplication app(argc, argv);
	QWidget* w = new QWidget();
	QVBoxLayout* box = new QVBoxLayout(w);
	//w->setLayout(box);
	QLabel* label = new QLabel(w);
	label->setText("hello");
	QLabel* label2 = new QLabel("label 2", w);
	box->addWidget(label);
	box->addWidget(label2);

	ASlot* aslot = new ASlot();
	QObject::connect(w, SIGNAL(destroyed(QObject*)), aslot, SLOT(destroyed(QObject*)));

	QShortcut* sc = new QShortcut(w);
	sc->setKey(Qt::Key_Return);
	QObject::connect(sc, SIGNAL(activated()), aslot, SLOT(activated()));

	w->show();
	return app.exec();
}

