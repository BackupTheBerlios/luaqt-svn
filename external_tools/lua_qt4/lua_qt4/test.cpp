#include <QApplication>
#include <QLabel>
#include <QVBoxLayout>

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

    w->show();
    return app.exec();
}
