# Astrafy — BI Engineer Take-Home Challenge

## Stack
- **dbt** — transformation & modélisation
- **BigQuery** — data warehouse
- **LookML / Looker** — semantic layer
- **Looker Studio** — dashboard business

---

## Installation & lancement

### Prérequis
- Python 3.11+
- dbt-bigquery
- Accès BigQuery configuré (service account ou `gcloud auth`)

### Setup

```bash
# 1. Cloner le repo
git clone [https://github.com/ilona08/Astrafy-take-home-challenge.git]
cd astrafy-bi-challenge/dbt

# 2. Installer les dépendances dbt
pip install dbt-bigquery

# 3. Copier et configurer le profil
cp profiles.yml.example ~/.dbt/profiles.yml
# → éditer avec tes credentials BigQuery

# 4. Vérifier la connexion
dbt debug

# 5. Lancer les modèles
dbt run

# 6. Lancer les tests
dbt test
```
---


## Structure du projet

```
astrafy-bi-challenge/
├── data/                         
│   ├── orders_recrutement.xlsx
│   └── sales_recrutement.xlsx
│
├── README.md
│
├── dbt_astrafy/
│   ├── dbt_project.yml
│   ├── profiles.yml.example
│   ├── models/
│   │   ├── staging/
│   │   │   ├── stg_orders.sql
│   │   │   ├── stg_sales.sql
│   │   │   └── schema.yml
│   │   ├── intermediate/
│   │   │   ├── int_orders_segmented.sql
│   │   │   └── schema.yml
│   │   └── marts/
│   │       ├── fct_orders.sql
│   │       ├── fct_orders_segmented.sql
│   │       └── schema.yml
│   └── .gitignore
│
├── lookml/
│   ├── models/
│   │   └── ecommerce.model.lkml
│   └── views/
│       ├── fct_orders_segmented.view.lkml
│       └── fct_sales.view.lkml
│
└── design/
    └── dashboard_mockup.pdf

```
---
Le fichier excel_to_csv.py permet d'écrire les fichiers de données dans le dossier seed de dbt 
---

## Part 1 — Coding Challenge (dbt + BigQuery)

### Exercice 1 à 3
Ils se trouvent dans la partie analyses du dossier dbt.

## Data Quality Summary

| Check | Result |
|---|---|
| Duplicate `order_id` in orders | 0 |
| Duplicate `order_id + product_id` in sales | 0 |
| Orders without associated sales lines | 0 |
| `net_sales` range | 1.77 – 824.01 |
| `qty` range | 1 – 50 |
| Date range | 2022-07-09 – 2023-12-31 |

### Architecture en couches

Le projet suit l'architecture dbt standard en 3 couches. Chaque couche a une responsabilité unique et ne peut interagir qu'avec la couche inférieure via `{{ ref() }}`.

```
Sources (BigQuery raw)
    ↓
Staging        → nettoyage, typage, renommage
    ↓
Intermediate   → logique métier complexe
    ↓
Marts          → tables finales exposées à Looker
```

Cette séparation garantit la maintenabilité : si une source change, seul le staging est impacté.

---

### Staging

**Responsabilité** : une seule — nettoyer les données sources. Aucune logique métier ici.

Choix techniques :
- Tous les identifiants (`order_id`, `client_id`, `product_id`) sont castés en `STRING` dès le staging (**"cast early, cast once"**). Raisons : éviter les opérations arithmétiques accidentelles, anticiper les évolutions de format (ex. `ORD-12345`), et supprimer les cast implicites coûteux lors des JOINs dans BigQuery.
- Les métriques quantitatives (`net_sales`, `qty`) restent en `NUMERIC`.
- Matérialisés en **view** — pas de stockage inutile sur BigQuery.

---

### Intermediate

**`int_orders.sql`** - question 4 

**`int_orders_segmented.sql`** - question 5 : logique de segmentation client sur fenêtre glissante 12 mois.

La segmentation est définie ainsi :
- **New** : 0 commande du même client dans les 12 mois précédant la commande
- **Returning** : entre 1 et 3 commandes dans les 12 mois précédents
- **VIP** : 4 commandes ou plus dans les 12 mois précédents

Approche retenue — **self-join** :

```sql
LEFT JOIN stg_orders o2
  ON  o1.client_id  = o2.client_id
  AND o2.order_date >= DATE_SUB(o1.order_date, INTERVAL 12 MONTH)
  AND o2.order_date <  o1.order_date
```

---

### Marts

Tables finales matérialisées en **table** (non en view) car consommées directement par Looker — la performance de lecture prime.

| Modèle | Description |
|--------|-------------|
| `fct_sales.sql` | Toutes les commandes 2022–2023 avec les produits |
| `fct_orders_segmented.sql` | Commandes 2023 avec colonne `order_segmentation` (ex. 6) |

---

### Tests dbt

Chaque modèle est couvert par des tests déclarés dans `schema.yml` :

```yaml
- name: order_id
  tests: [unique, not_null]

- name: order_segmentation
  tests:
    - accepted_values:
        values: ['New', 'Returning', 'VIP']
```

Lancer les tests :
```bash
dbt test
```

---

### Datasets BigQuery résultants

Grâce à la config `+schema` dans `dbt_project.yml`, les modèles sont organisés par dataset :

```
my-project-ilona/
  ├── dbt_astrafy_staging/
  │     ├── stg_orders      (view)
  │     └── stg_sales       (view)
  ├── dbt_astrafy_intermediate/
  │     └── int_orders_segmented  (view)
  └── dbt_astrafy_marts/
        ├── fct_orders             (table)
        └── fct_orders_segmented   (table)
```

---

## Part 2 — LookML Semantic Layer

### Structure

**`fct_orders_segmented.view.lkml`**
- Dimensions : `order_id` (PK), `client_id`, `order_date` (dimension_group avec timeframes), `order_segmentation`, `net_sales`
- Measures : `count_orders`, `count_customers` (count_distinct), `total_net_sales`

**`fct_sales.view.lkml`**
- Dimensions : `order_id`, `product_id`, `customer_id`, `order_date`
- Measures : `total_net_sales`, `total_qty`, `avg_qty_per_order`

**`ecommerce.model.lkml`**
- Un seul explore `fct_orders_segmented` avec un join `left_outer` sur `fct_sales`
- Relationship `one_to_many` sur `order_id` (1 commande → plusieurs produits)

---

## Part 3 — Design Challenge (Looker Studio)

### Lien dashboard
> [Dashboard Looker Studio](https://lookerstudio.google.com/s/rBAdSpfbgkE) 

### Structure du dashboard (2 pages)

**Page 1 — Segmentation client**


| Visualisation | KPI |
|--------------|-----|
| Scorecard | Nombre de clients, Nombre de commandes, CA total, AOV |
| Pie chart | Répartition New / Returning / VIP |
| Tableau | CA et nb commandes par segment |
| Stacked bar | Évolution mensuelle des segments |

**Page 2 — Performance produits**

| Visualisation | KPI |
|--------------|-----|
| Scorecard | Nb commandes moyen, Nb produits vendus |
| Bar chart horizontal | Top produits par CA |
| Combo chart | Nb produits moyen/commande + CA par mois |

---




