#!/usr/bin/env python
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'website_backend.settings')
django.setup()

from content.models import InvestorPageWhyCard, InvestorPageStrategy, InvestorPageQualification

# Clear existing data
InvestorPageWhyCard.objects.all().delete()
InvestorPageStrategy.objects.all().delete()
InvestorPageQualification.objects.all().delete()

# Why Prime Alpha cards
why_cards = [
    {
        'order': 1,
        'icon': '◆',
        'title_en': 'Patient Capital',
        'description_en': 'We deploy capital on a 3–7 year horizon, aligned with the real operating cycles of African businesses. No artificial urgency, no forced exits.',
        'title_fr': 'Capital Patient',
        'description_fr': 'Nous déployons des capitaux sur un horizon de 3 à 7 ans, aligné sur les cycles opérationnels réels des entreprises africaines.',
    },
    {
        'order': 2,
        'icon': '◆',
        'title_en': 'Pan-African Coverage',
        'description_en': 'Active presence across CEMAC and West African markets, with a growing U.S. Real Estate platform. Four strategies, one integrated framework.',
        'title_fr': 'Couverture Panafricaine',
        'description_fr': 'Présence active en CEMAC et Afrique de l\'Ouest, avec une plateforme Immobilier en croissance aux États-Unis.',
    },
    {
        'order': 3,
        'icon': '◆',
        'title_en': 'Verifiable Track Record',
        'description_en': '153.7% blended return across all capital ever deployed. Auditable. No outside capital for the first 11 months of operation.',
        'title_fr': 'Historique Vérifiable',
        'description_fr': '153,7% de rendement pondéré sur l\'ensemble des capitaux déployés. Auditable. Sans capital extérieur durant les 11 premiers mois.',
    },
    {
        'order': 4,
        'icon': '◆',
        'title_en': 'Institutional Standards',
        'description_en': 'IFRS accounting, quarterly LP reporting, IC-level governance, and zero-tolerance compliance policies regardless of market informality.',
        'title_fr': 'Standards Institutionnels',
        'description_fr': 'Comptabilité IFRS, reporting LP trimestriel, gouvernance IC, et politiques de conformité à tolérance zéro.',
    },
]

for card in why_cards:
    InvestorPageWhyCard.objects.create(**card)

# Fund Strategies
strategies = [
    {
        'order': 1,
        'code': 'PE',
        'name_en': 'Private Equity',
        'description_en': 'Controlling stakes in African mid-market businesses. 3–7yr hold.',
        'page': 'Private Equity',
        'name_fr': 'Private Equity',
        'description_fr': 'Participations dans les PME africaines. Horizon 3–7 ans.',
    },
    {
        'order': 2,
        'code': 'PC',
        'name_en': 'Private Credit',
        'description_en': 'Direct lending to under-banked West African companies. Zero drawdowns to date.',
        'page': 'Private Credit',
        'name_fr': 'Crédit Privé',
        'description_fr': 'Prêts directs aux PME non servies par les banques. Zéro défaut à ce jour.',
    },
    {
        'order': 3,
        'code': 'RE',
        'name_en': 'Real Estate',
        'description_en': 'U.S. residential and multifamily. Fix-and-flip, buy-and-hold. Currently fundraising.',
        'page': 'Real Estate',
        'name_fr': 'Immobilier',
        'description_fr': 'Résidentiel et multifamilial aux États-Unis. En levée de fonds.',
    },
    {
        'order': 4,
        'code': 'COM',
        'name_en': 'Commodities',
        'description_en': 'Physical commodity trading across textiles, agriculture, livestock. CEMAC corridor.',
        'page': 'Commodities',
        'name_fr': 'Matières Premières',
        'description_fr': 'Commerce de matières premières physiques en CEMAC.',
    },
]

for strat in strategies:
    InvestorPageStrategy.objects.create(**strat)

# Investor Qualifications
qualifications = [
    {
        'order': 1,
        'text_en': 'Qualified institutional investors (pension funds, endowments, insurance companies, sovereign wealth funds)',
        'text_fr': 'Investisseurs institutionnels qualifiés (fonds de pension, dotations, compagnies d\'assurance, fonds souverains)',
    },
    {
        'order': 2,
        'text_en': 'Family offices with $5M+ in investable assets and a minimum 3-year investment horizon',
        'text_fr': 'Family offices avec 5M$+ d\'actifs investissables et un horizon d\'investissement minimum de 3 ans',
    },
    {
        'order': 3,
        'text_en': 'High-net-worth individuals meeting accredited investor standards in their respective jurisdiction',
        'text_fr': 'Particuliers fortunés répondant aux critères d\'investisseur accrédité dans leur juridiction',
    },
    {
        'order': 4,
        'text_en': 'Strategic co-investors with sector expertise in African private markets',
        'text_fr': 'Co-investisseurs stratégiques avec expertise sectorielle dans les marchés privés africains',
    },
]

for qual in qualifications:
    InvestorPageQualification.objects.create(**qual)

print("✓ Investor page content populated successfully")
