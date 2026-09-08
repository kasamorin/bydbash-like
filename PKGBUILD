# Maintainer: kasamorin <kasamorin@localhost>
pkgname=bydbash-like
pkgver=1.0.0
pkgrel=4
pkgdesc="跨发行版 bash 配置：↳实际命令回显 / 计时 / git 状态 / 终端标题联动 / autocd-cdspell。安装时自动备份原配置，卸载时自动还原。"
arch=('any')
url=""
license=('MIT')
depends=('git' 'bash-completion' 'tree')
install=bydbash-like.install
options=('!strip' '!emptydirs')
backup=('home/kasamorin/.bashrc' 'home/kasamorin/.bash_profile')
source=('.bashrc' '.bash_profile')
sha256sums=('SKIP' 'SKIP')

package() {
    install -Dm644 -o "$USER" -g "$USER" \
        "$srcdir/.bashrc" "$pkgdir/$HOME/.bashrc"
    install -Dm644 -o "$USER" -g "$USER" \
        "$srcdir/.bash_profile" "$pkgdir/$HOME/.bash_profile"
}