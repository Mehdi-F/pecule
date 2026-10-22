"""Génère un relevé LCL FICTIF (mise en page calquée sur un vrai, données inventées) pour les tests.

Usage : python3 test/fixtures/make_fake_lcl_pdf.py test/fixtures/releve_lcl_fictif.pdf
"""
import sys

from reportlab.lib.pagesizes import portrait
from reportlab.pdfgen import canvas

W, H = 612, 864
FONT, SIZE = "Helvetica", 8.5
X_DATE, X_LABEL, X_CONT, X_VALUE = 42.5, 74.8, 80.8, 365.6
R_DEBIT, R_CREDIT = 480.7, 558.7


def text(c, x, top, s, size=SIZE):
    c.setFont(FONT, size)
    c.drawString(x, H - top - size, s)


def right(c, x_right, top, s):
    c.setFont(FONT, SIZE)
    c.drawRightString(x_right, H - top - SIZE, s)


def page_header(c, page_no, total):
    text(c, 180, 30, "RELEVE DE COMPTE", 12)
    text(c, 420, 60, "du 01.12.2025 au 31.01.2026 - N° 12")
    text(c, 38.9, 113.3, "M. JEAN TEST")
    text(c, 44.9, 162.0, "ECRITURES DE LA PERIODE")
    text(c, 41.6, 185.9, "DATE")
    text(c, 197.1, 185.9, "LIBELLE")
    text(c, 364.8, 185.9, "VALEUR")
    text(c, 432.8, 185.9, "DEBIT")
    text(c, 504.4, 185.9, "CREDIT")
    right(c, 570, 820, f"Page {page_no} / {total}")
    text(c, 40, 835, "Crédit Lyonnais-SA au capital de 1 euros - test", 6)


def op(c, top, date, label, value, debit=None, credit=None, cont=()):
    text(c, X_DATE, top, date)
    text(c, X_LABEL, top, label)
    text(c, X_VALUE, top, value)
    if debit:
        right(c, R_DEBIT, top, debit)
    if credit:
        right(c, R_CREDIT, top, credit)
    for i, line in enumerate(cont, 1):
        text(c, X_CONT, top + 12 * i, line)
    return top + 12 * (len(cont) + 1)


def main(out):
    c = canvas.Canvas(out, pagesize=portrait((W, H)))
    page_header(c, 1, 2)
    text(c, 300, 209.8, "ANCIEN SOLDE")
    right(c, R_CREDIT, 209.8, "1 000,00")
    y = 233.7
    y = op(c, y, "15.12", "CB CARREFOUR MARKET 14/12/25", "15.12.25", debit="42,50")
    y = op(c, y, "20.12", "VIR.PERMANENT Jean Revolut", "20.12.25", debit="200,00", cont=["Virement permanent"])
    y = op(c, y, "05.01", "VIREMENT CPAM DE PARIS", "05.01.26", credit="12,30",
           cont=["LIBELLE:123456", "REF.CLIENT:123456"])
    text(c, 540, y, "ZX12AB34")
    c.showPage()

    page_header(c, 2, 2)
    y = 209.8
    y = op(c, y, "10.01", "PRLV SEPA DIRECTION GENERALE DES FINANCES PUBLIQUE", "10.01.26", debit="1 234,56",
           cont=["S", "LIBELLE:IMPOT TEST", "ID.CREANCIER:FR00ZZZ000000"])
    y = op(c, y, "12.01", "CB LBB Lille 11/01/26", "12.01.26", debit="30,60")
    y = op(c, y, "14.01", "VIR INST PAULINE TEST", "14.01.26", credit="30,60", cont=["LIBELLE:La Belle Boucle"])
    y = op(c, y, "20.01", "VIREMENT EMPLOYEUR SAS", "20.01.26", credit="2 109,54",
           cont=["LIBELLE:SALARY 01-2026 Employeur", "NATURE DU PAIEMENT:SALA"])
    text(c, 300, y + 6, "TOTAUX")
    right(c, R_DEBIT, y + 6, "1 507,66")
    right(c, R_CREDIT, y + 6, "3 152,44")
    text(c, X_DATE, y + 24, "31.01")
    text(c, 290, y + 24, "SOLDE EN EUROS")
    right(c, R_CREDIT, y + 24, "1 644,78")
    text(c, X_DATE, y + 60, "Récapitulatif des frais perçus du 01/12/2025 au 31/12/2025")
    text(c, 460, y + 60, "DEBIT")
    text(c, 520, y + 60, "CREDIT")
    text(c, X_DATE, y + 74, "CARTES ET ESPECES")
    right(c, R_DEBIT, y + 74, "8,06")
    c.save()


if __name__ == "__main__":
    main(sys.argv[1])
