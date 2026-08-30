# Vietnam Real Estate Market Analysis & Data Warehouse



**Transforming 30,229 noisy, scraped property listings into a verified Star Schema to analyze real estate valuation drivers and detect market anomalies across Vietnam.**



![PostgreSQL](https://img.shields.io/badge/Database-PostgreSQL-blue?style=flat-square&logo=postgresql)
![SQL](https://img.shields.io/badge/Language-100%25_SQL-green?style=flat-square)
![Data Model](https://img.shields.io/badge/Schema-Kimball_Star_Schema-brightgreen?style=flat-square)
![Data Quality](https://img.shields.io/badge/Integrity-0%25_NULL_FKs-success?style=flat-square)



\---



## Executive Summary



### The Business Problem

The digital real estate market in Vietnam is rapidly expanding, but publicly listed property data is notoriously fragmented and noisy. Free-text address formats, aggressive broker spam (duplicate listings), and inconsistent data conventions prevent buyers, investors, and analysts from obtaining a transparent view of actual property values. 


### The Objective

This project serves as a centralized analytical engine designed to answer critical market questions:

\* \*\*Valuation Drivers:\*\* How do geographic location, legal ownership status , and furnishing condition quantitatively impact price per square meter?

\* \*\*Market Anomaly Detection:\*\* Which listings are statistically underpriced or overpriced (outliers) relative to their localized micro-market?

\* \*\*Scalable Data Foundation:\*\* How to structure unstructured web-scraped listings into an relational Data Warehouse (Star Schema) that guarantees 100% data integrity before reporting.



\---



## Key Metrics at a Glance



| Metric | Value | Business / Technical Significance |

| :--- | :--- | :--- |

| \*\*Raw Listings Processed\*\* | `30,229` | Initial volume of raw, unstructured listings scraped from online portals. |

| \*\*Spam / Duplicates Purged\*\* | `2,699` (8.9%) | Duplicate broker listings removed to prevent skewed average price metrics. |

| \*\*Cleaned Production Records\*\* | `27,527` (91.1%) | Verified master records retained for downstream dimensional analysis. |

| \*\*Foreign Key Integrity\*\* | `100%` (0% NULL) | Zero orphan records across all Fact-to-Dimension joins. |

| \*\*Key Questions Answered\*\* | `6` Scenarios | Covering pricing tiers, legal premiums, Z-score outliers, and district rankings. |



\---



##  Dataset Overview \& Provenance



### 1. Data Source \& Scope

\* \*\*Source:\*\* Secondary residential real estate listings aggregated from prominent Vietnamese online property portals (e.g., \*Batdongsan.com\*).

\* \*\*Geographic Coverage:\*\* Major metropolitan areas and economic hubs in Vietnam, predominantly centered around \*\*Hanoi, Ho Chi Minh City, Binh Duong, and neighboring provinces\*\*.

\* \*\*Property Segment:\*\* Urban residential properties (townhouses, private houses, residential plots) spanning price points from 1.0 to 11.5+ billion VND.




