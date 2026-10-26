#include <QCoreApplication>
#include <QFileInfo>
#include <QDebug>
#include <sys/stat.h>
#include "kwalletbackend.h"

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    umask(0077);

    const QString name = QStringLiteral("kdewallet");
    const QString path = KWallet::Backend::getSaveLocation() + QStringLiteral("/kdewallet.kwl");
    // Preserve existing wallets, including empty or damaged files.
    if (QFileInfo::exists(path) || QFileInfo(path).isSymLink()) {
        return 0;
    }

    KWallet::Backend wallet(name);
    wallet.setCipherType(KWallet::BACKEND_CIPHER_BLOWFISH);
    const int result = wallet.open(QByteArray(""));
    if (result != 0) {
        qCritical() << "Could not initialize kdewallet:" << result;
        return 1;
    }
    wallet.createFolder(QStringLiteral("Passwords"));
    wallet.createFolder(QStringLiteral("Form Data"));
    return wallet.close(true) == 0 ? 0 : 1;
}
