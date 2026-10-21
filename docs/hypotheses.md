# Hypothèses et limites : test technique Equancy

Document de travail. Chaque hypothèse est datée du moment où elle est prise, avec sa justification et son impact.
Statut : **Décidée** (déjà appliquée dans le pipeline) ou **À valider** (proposée, pas encore appliquée).

## 1. Périmètre et définitions

| # | Hypothèse | Justification | Impact | Statut |
|---|---|---|---|---|
| H1 | Un « pays » est un État souverain. Les territoires (Guam, Martinique, Groenland, Hong Kong, Porto Rico…) et les agrégats (Global, International Transport) sont exclus des classements, mais gardés dans la dimension pays avec leur type. | Un choix d'implantation concerne des États. Les micro-territoires faussent les croissances et les valeurs par habitant (ex. Sint Maarten en 1954 : 834 tCO₂ par habitant). | 195 pays classés, 44 territoires et 2 agrégats exclus des classements. | Décidée |
| H2 | Taïwan et le Kosovo sont classés « territoire ». | Non membres de l'ONU, présents uniquement dans le fichier des émissions (aucun PIB ni population). Leur classement n'aurait pas été possible. | Aucun effet sur les résultats des questions a et b. | Décidée |
| H3 | Sept entrées de `Country_Table` sont reclassées « territoire » : Aruba, Bermudes, Curaçao, Hong Kong, Macao, Porto Rico, Turks-et-Caïcos. | Présentes dans le référentiel mais non souveraines. | 7 entités retirées des classements. | Décidée |
| H4 | La jointure entre tables se fait sur le code pays ISO alpha-3, jamais sur le nom. Un seul nom officiel par code (table de référence `country_classification`). | 20 codes ont deux noms selon le fichier (ex. Czechia / Czech Republic, GBR, KOR…). | Aucun pays perdu à la jointure. | Décidée |
| H5 | `Country_Table` n'est pas utilisée comme liste officielle. La dimension pays est construite à partir de tous les codes présents dans les sources. | `Country_Table` compte 168 pays et ne contient pas 73 codes présents dans les données (Chine, Nigeria, Égypte, Arabie saoudite, Maroc…). | Les grands pays absents du référentiel restent dans l'analyse. | Décidée |

## 2. Données et qualité

| # | Hypothèse | Justification | Impact | Statut |
|---|---|---|---|---|
| H6 | Le fichier « préservation du patrimoine » est exclu de l'analyse. | Plusieurs valeurs pour un même pays et une même année (113 couples en doublon), sans colonne pour les distinguer. Une colonne de ventilation a probablement été perdue à l'export. Le test d'unicité dbt le prouve (alerte voulue). | Aucune analyse ne repose sur ce fichier. | Décidée |
| H7 | Les valeurs manquantes restent vides (NULL). Elles ne sont jamais remplacées par zéro ni par une moyenne. | Remplacer inventerait des données. | Les pays incomplets sont exclus des calculs concernés, pas des autres. | Décidée |
| H8 | La période est une année entière (2010, 2011…), pas une date. | Toutes les données sont annuelles. Le « 01/01 » n'apporte aucune information. | Toutes les tables se joignent sur la même colonne `year`. | Décidée |
| H9 | Les unités non précisées sont déduites des ordres de grandeur : PIB en dollars US, émissions en millions de tonnes de CO₂ (MtCO₂), émissions par habitant en tonnes de CO₂ par habitant. | Global vaut 37 124 en 2021 (37,1 Gt, cohérent avec le total mondial). France 2021 : PIB ≈ 2,96E+12. | À confirmer auprès de la source si possible. | Décidée |
| H10 | Le PIB est utilisé tel quel, avec une précision de 3 chiffres significatifs sur 27 % des lignes (notation scientifique). | Précision perdue dans le fichier d'origine, non récupérable. | Imprécision d'au plus 0,5 % sur ces valeurs. Négligeable pour un classement de croissance, sauf pour deux pays très proches. | Décidée |
| H11 | Les entités historiques ou sans code ISO du fichier des émissions sont exclues (French West Africa, Kuwaiti Oil Fires, Ryukyu Islands…). L'entité « St. Kitts-Nevis-Anguilla », qui partage le code KNA avec Saint Kitts and Nevis, est aussi exclue. | Sans code, impossible de les joindre. Le code partagé doublerait les lignes. | 6 entités sans code + 1 entité à code partagé écartées. | Décidée |
| H12 | Les dépenses d'éducation couvrent 2010-2022 avec un panel très incomplet (7,2 années par pays en moyenne, 13 valeurs manquantes). | Limite du fichier source. | Prudence sur les évolutions et les comparaisons entre pays. | Décidée |
| H13 | La population rurale est un critère de contexte. Elle compte 120 valeurs manquantes (10 pays par année), non comblées. | Hors des trois questions posées. | Un pays sans cette valeur n'est simplement pas évalué sur ce critère. | Décidée |

## 3. Choix propres aux trois questions

| # | Hypothèse | Justification | Impact | Statut |
|---|---|---|---|---|
| H14 | **Question a** : la croissance du PIB est la variation en % entre une année de départ et une année d'arrivée choisies par l'utilisateur dans le dashboard (par défaut 2010 et 2021). Fenêtre disponible : 2000-2021. | L'énoncé demande « entre deux années données ». | Les pays sans PIB pour l'une des deux années sont exclus du classement (182 pays disposent des deux valeurs pour 2010 et 2021 ; 183 pays ont un PIB en 2021 contre 192 en 2010). | À valider |
| H15 | **Question a** : un filtre de taille minimale de PIB évite que de petites économies dominent le classement. Seuil à fixer. | Les petites économies affichent des taux de croissance spectaculaires peu significatifs. | À documenter avec la valeur retenue. | À valider |
| H16 | **Question b** : le niveau d'éducation est approché par les dépenses publiques d'éducation par habitant (millions de dollars constants ÷ population en milliers, avec conversion des unités). | Aucun fichier ne contient un niveau d'éducation (scolarisation, diplômes). La dépense mesure l'effort, pas le résultat. | Limite à écrire dans le dashboard. | À valider |
| H17 | **Question b** : la corrélation est celle de Pearson, calculée sur la fenêtre **2010-2018** (moyenne par pays sur ces années, ou une année de référence comme 2017). Les années 2019-2021 sont écartées pour cette question. | Le fichier d'éducation compte environ 105 à 120 pays par année de 2010 à 2018, puis 85 en 2019, 34 en 2020 et 26 en 2021. Sur 2021, la corrélation reposerait sur 24 pays seulement. | Environ 105 à 115 pays comparables. Résultat qui peut varier selon l'année : le montrer. | À valider |
| H18 | **Question b** : une corrélation ne prouve pas une causalité. Le PIB par habitant influence probablement à la fois les émissions et les dépenses d'éducation. | Variable de confusion évidente. | À dire explicitement, et le PIB par habitant peut être ajouté en contexte. | À valider |
| H19 | **Question c** : l'empreinte carbone par habitant est la colonne `Per Capita` du fichier des émissions. L'évolution est montrée sur une période récente (par exemple 20 ans, 2000-2021) ; l'historique depuis 1950 reste disponible pour le contexte. | Donnée fournie à la source, pas de recalcul. Les 192 pays ont une valeur chaque année de 1950 à 2021 ; avant 1950, seuls 12 à 20 pays sont couverts. | Les pays sans valeur par habitant sont exclus du classement. | À valider |
| H20 | **Question c** : un filtre de population minimale écarte les micro-États. Seuil à fixer. | Leur valeur par habitant est instable. En 2021, 35 pays ont moins d'un million d'habitants et 66 moins de cinq millions. | À documenter avec la valeur retenue. | À valider |
| H21 | Chaque question a sa propre fenêtre d'analyse, définie par les fichiers qu'elle utilise : a = 2000-2021 (PIB), b = 2010-2018 (éducation + émissions par habitant + population), c = 1950-2021 (émissions, avec un affichage récent par défaut). Les années antérieures du fichier des émissions (1750-1949) restent en staging mais ne sont pas reprises dans les tables de faits. | Les fichiers couvrent des périodes différentes. Une fenêtre unique de 2010-2021 écarterait des données utiles (PIB avant 2010) et fragiliserait la question b (éducation presque vide après 2018). | Aucune donnée détruite : seul le périmètre des analyses est restreint. | À valider |
| H22 | La « zone d'implantation » est un résultat à plusieurs niveaux : une présélection de 3 à 5 pays, avec une recommandation principale, sans découpage régional. | Les données ne permettent pas de désigner un unique pays ; un découpage régional demanderait un référentiel absent des fichiers. | Le dashboard présente un classement argumenté et ses limites. | À valider |
| H23 | Aucune donnée ne disparaît en silence : une table de couverture (pays × variable : première et dernière année, nombre d'années, complétude) est produite et affichée dans le dashboard. | Deux pays n'ont aucun PIB (Corée du Nord, Vatican) et 35 pays n'ont aucune donnée d'éducation. | Les pays absents d'un classement sont visibles avec la raison. | À valider |

## 4. Preuves de qualité

- 39 tests dbt sur les 8 modèles de staging : 38 réussis, 1 alerte volontaire (unicité du fichier patrimoine).
- Contrôle des volumes à l'ingestion : les 8 tables ont exactement le nombre de lignes attendu.
- Vérification manuelle d'une valeur : PIB de l'Autriche en 2004, proche de 301 milliards.

## 5. Limites générales

- Les données ne permettent pas de mesurer un niveau d'éducation réel.
- Les unités ne sont pas confirmées par la source.
- Le panel d'éducation est incomplet : les comparaisons entre pays restent indicatives.
- Un choix d'implantation réel ferait intervenir bien d'autres critères (coûts, infrastructures, risque politique) absents de ces données.

## 6. Journal des décisions à compléter

À remplir au fil du projet (seuils retenus, années choisies, décisions prises sur les marts) :

- Seuil de PIB minimal (H15) :
- Année de référence pour la corrélation (H17) :
- Seuil de population minimale (H20) :
