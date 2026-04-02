--
-- PostgreSQL database dump
--

\restrict Xri38YcoTAyIokLB2bT0q4jK2vcp34oECQhyyEVLmQr089oWN7uJ8mH9HmLLzAZ

-- Dumped from database version 16.13
-- Dumped by pg_dump version 16.13

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: allenatori; Type: TABLE; Schema: public; Owner: registro_user
--

CREATE TABLE public.allenatori (
    id integer NOT NULL,
    cognome character varying(100) NOT NULL,
    telefono character varying(30)
);


ALTER TABLE public.allenatori OWNER TO registro_user;

--
-- Name: allenatori_id_seq; Type: SEQUENCE; Schema: public; Owner: registro_user
--

CREATE SEQUENCE public.allenatori_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.allenatori_id_seq OWNER TO registro_user;

--
-- Name: allenatori_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: registro_user
--

ALTER SEQUENCE public.allenatori_id_seq OWNED BY public.allenatori.id;


--
-- Name: categorie; Type: TABLE; Schema: public; Owner: registro_user
--

CREATE TABLE public.categorie (
    id integer NOT NULL,
    nome character varying(100) NOT NULL,
    anno integer,
    giorni character varying(20),
    stagione integer,
    is_portieri integer DEFAULT 0,
    is_archiviata integer DEFAULT 0,
    drive_folder_id character varying(100),
    societa_id integer
);


ALTER TABLE public.categorie OWNER TO registro_user;

--
-- Name: categorie_id_seq; Type: SEQUENCE; Schema: public; Owner: registro_user
--

CREATE SEQUENCE public.categorie_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.categorie_id_seq OWNER TO registro_user;

--
-- Name: categorie_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: registro_user
--

ALTER SEQUENCE public.categorie_id_seq OWNED BY public.categorie.id;


--
-- Name: codici; Type: TABLE; Schema: public; Owner: registro_user
--

CREATE TABLE public.codici (
    codice character varying(5) NOT NULL,
    descrizione character varying(100),
    tipo character varying(20)
);


ALTER TABLE public.codici OWNER TO registro_user;

--
-- Name: convocazione_gare; Type: TABLE; Schema: public; Owner: registro_user
--

CREATE TABLE public.convocazione_gare (
    id integer NOT NULL,
    convocazione_id integer,
    numero integer NOT NULL,
    gara character varying(200),
    data date,
    campo character varying(200),
    indirizzo character varying(200),
    appuntamento character varying(50),
    inizio_gara character varying(50),
    allenatore character varying(200)
);


ALTER TABLE public.convocazione_gare OWNER TO registro_user;

--
-- Name: convocazione_gare_id_seq; Type: SEQUENCE; Schema: public; Owner: registro_user
--

CREATE SEQUENCE public.convocazione_gare_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.convocazione_gare_id_seq OWNER TO registro_user;

--
-- Name: convocazione_gare_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: registro_user
--

ALTER SEQUENCE public.convocazione_gare_id_seq OWNED BY public.convocazione_gare.id;


--
-- Name: convocazione_giocatori; Type: TABLE; Schema: public; Owner: registro_user
--

CREATE TABLE public.convocazione_giocatori (
    id integer NOT NULL,
    gara_id integer,
    persona_id integer,
    posizione integer NOT NULL
);


ALTER TABLE public.convocazione_giocatori OWNER TO registro_user;

--
-- Name: convocazione_giocatori_id_seq; Type: SEQUENCE; Schema: public; Owner: registro_user
--

CREATE SEQUENCE public.convocazione_giocatori_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.convocazione_giocatori_id_seq OWNER TO registro_user;

--
-- Name: convocazione_giocatori_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: registro_user
--

ALTER SEQUENCE public.convocazione_giocatori_id_seq OWNED BY public.convocazione_giocatori.id;


--
-- Name: convocazioni; Type: TABLE; Schema: public; Owner: registro_user
--

CREATE TABLE public.convocazioni (
    id integer NOT NULL,
    categoria_id integer,
    data_inizio date NOT NULL,
    note character varying(1000),
    data_fine date,
    societa_id integer
);


ALTER TABLE public.convocazioni OWNER TO registro_user;

--
-- Name: convocazioni_id_seq; Type: SEQUENCE; Schema: public; Owner: registro_user
--

CREATE SEQUENCE public.convocazioni_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.convocazioni_id_seq OWNER TO registro_user;

--
-- Name: convocazioni_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: registro_user
--

ALTER SEQUENCE public.convocazioni_id_seq OWNED BY public.convocazioni.id;


--
-- Name: gruppi; Type: TABLE; Schema: public; Owner: registro_user
--

CREATE TABLE public.gruppi (
    id integer NOT NULL,
    nome character varying(100) NOT NULL
);


ALTER TABLE public.gruppi OWNER TO registro_user;

--
-- Name: gruppi_id_seq; Type: SEQUENCE; Schema: public; Owner: registro_user
--

CREATE SEQUENCE public.gruppi_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.gruppi_id_seq OWNER TO registro_user;

--
-- Name: gruppi_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: registro_user
--

ALTER SEQUENCE public.gruppi_id_seq OWNED BY public.gruppi.id;


--
-- Name: persone; Type: TABLE; Schema: public; Owner: registro_user
--

CREATE TABLE public.persone (
    id integer NOT NULL,
    nome character varying(100) NOT NULL,
    cognome character varying(100) NOT NULL,
    gruppo_id integer,
    categoria_id integer,
    data_nascita date,
    codice_fiscale character varying(16),
    telefono character varying(50),
    matricola character varying(50),
    numero_maglia integer,
    scadenza_certificato date,
    societa_id integer
);


ALTER TABLE public.persone OWNER TO registro_user;

--
-- Name: persone_id_seq; Type: SEQUENCE; Schema: public; Owner: registro_user
--

CREATE SEQUENCE public.persone_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.persone_id_seq OWNER TO registro_user;

--
-- Name: persone_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: registro_user
--

ALTER SEQUENCE public.persone_id_seq OWNED BY public.persone.id;


--
-- Name: registro; Type: TABLE; Schema: public; Owner: registro_user
--

CREATE TABLE public.registro (
    id integer NOT NULL,
    persona_id integer NOT NULL,
    data date NOT NULL,
    codice character varying(5),
    categoria_id integer,
    societa_id integer
);


ALTER TABLE public.registro OWNER TO registro_user;

--
-- Name: registro_id_seq; Type: SEQUENCE; Schema: public; Owner: registro_user
--

CREATE SEQUENCE public.registro_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.registro_id_seq OWNER TO registro_user;

--
-- Name: registro_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: registro_user
--

ALTER SEQUENCE public.registro_id_seq OWNED BY public.registro.id;


--
-- Name: societa; Type: TABLE; Schema: public; Owner: registro_user
--

CREATE TABLE public.societa (
    id integer NOT NULL,
    nome character varying(100) NOT NULL,
    nome_breve character varying(50),
    logo character varying(200),
    logosponsor character varying(200),
    colore_primario character varying(7),
    colore_secondario character varying(7),
    is_attiva integer
);


ALTER TABLE public.societa OWNER TO registro_user;

--
-- Name: societa_id_seq; Type: SEQUENCE; Schema: public; Owner: registro_user
--

CREATE SEQUENCE public.societa_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.societa_id_seq OWNER TO registro_user;

--
-- Name: societa_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: registro_user
--

ALTER SEQUENCE public.societa_id_seq OWNED BY public.societa.id;


--
-- Name: utente_categorie; Type: TABLE; Schema: public; Owner: registro_user
--

CREATE TABLE public.utente_categorie (
    id integer NOT NULL,
    utente_id integer,
    categoria_id integer,
    ruolo character varying(20) DEFAULT 'mister'::character varying
);


ALTER TABLE public.utente_categorie OWNER TO registro_user;

--
-- Name: utente_categorie_id_seq; Type: SEQUENCE; Schema: public; Owner: registro_user
--

CREATE SEQUENCE public.utente_categorie_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.utente_categorie_id_seq OWNER TO registro_user;

--
-- Name: utente_categorie_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: registro_user
--

ALTER SEQUENCE public.utente_categorie_id_seq OWNED BY public.utente_categorie.id;


--
-- Name: utenti; Type: TABLE; Schema: public; Owner: registro_user
--

CREATE TABLE public.utenti (
    id integer NOT NULL,
    username character varying(100) NOT NULL,
    password_hash character varying(200) NOT NULL,
    is_admin integer,
    nome character varying(100) DEFAULT ''::character varying,
    cognome character varying(100) DEFAULT ''::character varying,
    data_nascita date DEFAULT '1990-01-01'::date,
    codice_fiscale character varying(16) DEFAULT ''::character varying,
    cellulare character varying(50) DEFAULT ''::character varying,
    tesserino character varying(50),
    ruolo character varying(20) DEFAULT 'mister'::character varying,
    societa_id integer,
    is_super_admin integer DEFAULT 0
);


ALTER TABLE public.utenti OWNER TO registro_user;

--
-- Name: utenti_id_seq; Type: SEQUENCE; Schema: public; Owner: registro_user
--

CREATE SEQUENCE public.utenti_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.utenti_id_seq OWNER TO registro_user;

--
-- Name: utenti_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: registro_user
--

ALTER SEQUENCE public.utenti_id_seq OWNED BY public.utenti.id;


--
-- Name: allenatori id; Type: DEFAULT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.allenatori ALTER COLUMN id SET DEFAULT nextval('public.allenatori_id_seq'::regclass);


--
-- Name: categorie id; Type: DEFAULT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.categorie ALTER COLUMN id SET DEFAULT nextval('public.categorie_id_seq'::regclass);


--
-- Name: convocazione_gare id; Type: DEFAULT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.convocazione_gare ALTER COLUMN id SET DEFAULT nextval('public.convocazione_gare_id_seq'::regclass);


--
-- Name: convocazione_giocatori id; Type: DEFAULT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.convocazione_giocatori ALTER COLUMN id SET DEFAULT nextval('public.convocazione_giocatori_id_seq'::regclass);


--
-- Name: convocazioni id; Type: DEFAULT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.convocazioni ALTER COLUMN id SET DEFAULT nextval('public.convocazioni_id_seq'::regclass);


--
-- Name: gruppi id; Type: DEFAULT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.gruppi ALTER COLUMN id SET DEFAULT nextval('public.gruppi_id_seq'::regclass);


--
-- Name: persone id; Type: DEFAULT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.persone ALTER COLUMN id SET DEFAULT nextval('public.persone_id_seq'::regclass);


--
-- Name: registro id; Type: DEFAULT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.registro ALTER COLUMN id SET DEFAULT nextval('public.registro_id_seq'::regclass);


--
-- Name: societa id; Type: DEFAULT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.societa ALTER COLUMN id SET DEFAULT nextval('public.societa_id_seq'::regclass);


--
-- Name: utente_categorie id; Type: DEFAULT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.utente_categorie ALTER COLUMN id SET DEFAULT nextval('public.utente_categorie_id_seq'::regclass);


--
-- Name: utenti id; Type: DEFAULT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.utenti ALTER COLUMN id SET DEFAULT nextval('public.utenti_id_seq'::regclass);


--
-- Data for Name: allenatori; Type: TABLE DATA; Schema: public; Owner: registro_user
--

COPY public.allenatori (id, cognome, telefono) FROM stdin;
\.


--
-- Data for Name: categorie; Type: TABLE DATA; Schema: public; Owner: registro_user
--

COPY public.categorie (id, nome, anno, giorni, stagione, is_portieri, is_archiviata, drive_folder_id, societa_id) FROM stdin;
6	Esordienti	2013	1,3,4	2025	0	0	\N	1
8	Pulcini	2015	2,3,5	2025	0	0	\N	1
7	Pulcini	2016	1,3,5	2025	0	0	\N	1
9	Primi Calci	2017	1,3,4	2025	0	0	\N	1
11	Portieri Scuola Calcio	\N	3,5	2025	1	0	\N	1
1	Esordienti	2014	1,2,4	2025	0	0	1wR-kbWAAEVI716_u8LI14iKim4nsF1SF	1
13	TEST	2024	1,3,6	2025	0	0	\N	2
14	TEST2	2013	1,3,5	2025	0	0	\N	2
\.


--
-- Data for Name: codici; Type: TABLE DATA; Schema: public; Owner: registro_user
--

COPY public.codici (codice, descrizione, tipo) FROM stdin;
X	Presente	presenza
AG	Assente giustificato	assenza
AI	Assente ingiustificato	assenza
P	Allen. Portieri	extra
R	Recupero altra cat.	extra
\.


--
-- Data for Name: convocazione_gare; Type: TABLE DATA; Schema: public; Owner: registro_user
--

COPY public.convocazione_gare (id, convocazione_id, numero, gara, data, campo, indirizzo, appuntamento, inizio_gara, allenatore) FROM stdin;
34	2	1	RED TIGERS 1957 - ACC. MORETTI	2026-03-28	BLACK TIGERS STADIUM	VIA DEI RUDERI TORRENOVA, 2 ROMA	09:45	10:30	Grillo
35	2	2		2026-03-28	TIGERS STADIUM				
36	2	3		2026-03-28					
37	2	4		2026-03-28					
\.


--
-- Data for Name: convocazione_giocatori; Type: TABLE DATA; Schema: public; Owner: registro_user
--

COPY public.convocazione_giocatori (id, gara_id, persona_id, posizione) FROM stdin;
\.


--
-- Data for Name: convocazioni; Type: TABLE DATA; Schema: public; Owner: registro_user
--

COPY public.convocazioni (id, categoria_id, data_inizio, note, data_fine, societa_id) FROM stdin;
2	1	2026-03-28	PRESENTARSI ALL'APPUNTAMENTO IN ORARIO STABILITO ED IN TENUTA DA RAPPRESENTANZA GEMS (NO GIA CAMBIATI).\nSI GIOCA CON KIT GARA* (MAGLIA CALZONCINI E CALZETTONI) PORTARE FELPA D'ALLENAMENTO PER RISCALDAMENTO E K-WAY IN BORSA PER L'EVENIENZA.\nAVVISARE TEMPESTIVAMENTE L'ALLENATORE PRESENTE IN GARA IN CASO DI RITARDO O ASSENZA.\n*PORTARE COMUNQUE MAGLIA DI RICAMBIO, CALZONCINI E CALZETTONI PER MODIFICARE I COLORI IN BASE ALL'AVVERSARIO.	2026-03-29	1
\.


--
-- Data for Name: gruppi; Type: TABLE DATA; Schema: public; Owner: registro_user
--

COPY public.gruppi (id, nome) FROM stdin;
1	PRIMO GRUPPO
2	SECONDO GRUPPO
3	TERZO GRUPPO
4	PORTIERI
\.


--
-- Data for Name: persone; Type: TABLE DATA; Schema: public; Owner: registro_user
--

COPY public.persone (id, nome, cognome, gruppo_id, categoria_id, data_nascita, codice_fiscale, telefono, matricola, numero_maglia, scadenza_certificato, societa_id) FROM stdin;
3	Francesco	Alfonsi	1	\N	\N	\N	\N	\N	\N	\N	1
4	Andrea	Artiglio	1	\N	\N	\N	\N	\N	\N	\N	1
5	Luca	Badragan	1	\N	\N	\N	\N	\N	\N	\N	1
6	Gabriele	Barillaro	1	\N	\N	\N	\N	\N	\N	\N	1
10	Cristiano	Comerci	2	1	\N	\N	\N	\N	\N	\N	1
7	Francesco	Alfonsi	1	1	2014-11-19	LFNFNC14S19H501K	3381084734 / 3319259991	3512056	20	2026-08-29	1
8	Andrea	Artiglio	1	1	2014-10-29	RTGNDR14R29H501E	3492822723	3794806	25	2026-09-15	1
11	Luca	Badragan	1	1	2014-06-26	BDRLCU14H29H501H	3884793248	3759076	23	2026-08-28	1
14	Cristiano	Barbaro	3	1	2014-05-30	BRBCST14E30H501J	3462674149	3794667	43	2026-09-15	1
9	Antonio	Cante	2	1	2014-03-13	CNTNTN14C14F839J	3381596633	\N	21	2025-10-10	1
15	Gabriele	Barillaro	1	1	2014-04-24	BRLGRL14D24H501K	3510343981 / 3489388415	3805253	22	2026-09-17	1
16	Dario	Cacurri	3	1	2014-09-15	CCRDRA14P15H501P	\N	\N	\N	\N	1
\.


--
-- Data for Name: registro; Type: TABLE DATA; Schema: public; Owner: registro_user
--

COPY public.registro (id, persona_id, data, codice, categoria_id, societa_id) FROM stdin;
1	7	2026-03-02	X	1	1
2	7	2026-03-03	X	1	1
3	7	2026-03-05	X	1	1
4	7	2026-03-09	X	1	1
5	7	2026-03-10	AG	1	1
6	7	2026-03-12	R	1	1
7	7	2026-03-16	X	1	1
8	7	2026-03-17	X	1	1
9	7	2026-03-19	X	1	1
10	7	2026-03-23	X	1	1
11	7	2026-03-24	X	1	1
12	8	2026-03-02	X	1	1
13	8	2026-03-03	X	1	1
14	8	2026-03-05	AG	1	1
15	8	2026-03-09	X	1	1
16	8	2026-03-10	X	1	1
17	8	2026-03-12	X	1	1
18	8	2026-03-16	X	1	1
19	8	2026-03-17	X	1	1
20	8	2026-03-19	X	1	1
21	8	2026-03-23	X	1	1
22	8	2026-03-24	X	1	1
23	9	2026-03-02	X	1	1
24	9	2026-03-03	X	1	1
25	9	2026-03-05	X	1	1
26	9	2026-03-09	X	1	1
27	9	2026-03-10	X	1	1
28	9	2026-03-12	X	1	1
29	9	2026-03-16	X	1	1
30	9	2026-03-17	X	1	1
31	9	2026-03-19	X	1	1
32	9	2026-03-23	X	1	1
33	9	2026-03-24	X	1	1
34	9	2026-03-26	\N	1	1
35	10	2026-03-02	AG	1	1
36	10	2026-03-03	AG	1	1
37	10	2026-03-05	AG	1	1
38	10	2026-03-09	X	1	1
39	10	2026-03-10	X	1	1
40	10	2026-03-12	AG	1	1
41	10	2026-03-16	AG	1	1
42	10	2026-03-17	AG	1	1
43	10	2026-03-19	AG	1	1
44	10	2026-03-23	AG	1	1
45	10	2026-03-24	AG	1	1
46	11	2026-03-02	X	1	1
\.


--
-- Data for Name: societa; Type: TABLE DATA; Schema: public; Owner: registro_user
--

COPY public.societa (id, nome, nome_breve, logo, logosponsor, colore_primario, colore_secondario, is_attiva) FROM stdin;
1	RedTigers 1957	RedTigers	logo_logo.jpg	logosponsor_logosponsor.png	#dc2626	#1f2937	1
2	CLUB VALLI	\N	logo_logosponsor.png	logosponsor_logo.jpg	#2cdd4a	#d0f288	1
\.


--
-- Data for Name: utente_categorie; Type: TABLE DATA; Schema: public; Owner: registro_user
--

COPY public.utente_categorie (id, utente_id, categoria_id, ruolo) FROM stdin;
9	3	1	dirigente
10	4	1	\N
\.


--
-- Data for Name: utenti; Type: TABLE DATA; Schema: public; Owner: registro_user
--

COPY public.utenti (id, username, password_hash, is_admin, nome, cognome, data_nascita, codice_fiscale, cellulare, tesserino, ruolo, societa_id, is_super_admin) FROM stdin;
5	avalli	$2b$12$2J1kAzmKMqKAI02m1GvMhOHwYNkOMvl0kmEvc5DuuXjq3WCA1TMTe	1	Andrea	Valli	\N	\N	\N	\N	admin	2	0
1	admin	$2b$12$5eBIJth5MoeJ1TcnSS844uhlgSM95f/eQ7IdYPI/hnmrhfHupPR9W	1	Admin	Admin	1990-01-01	JVBEJBVJBDNVNFV	65165165151	\N	super_admin	1	1
3	agrillo	$2b$12$rjOO.zPvUqXEWGcwcm0cBOV4HK34gnOLdnpSqe4tcb8RIw2Cgx1BG	0	Andrea	Grillo	1982-07-30	GRLNDR82L30H501S	3494544193	\N	mister	1	0
4	afranconieri	$2b$12$Uz6AhBYKm.JlSu.KveEVrO40.9/F7H6P2w1ZBtxbYb48yNwaqdku.	0	Angelo	Franconieri	1976-10-06	FRNNGL76R06H501Z	3313653311	\N	dirigente	1	0
2	asergi	$2b$12$1d3UpDFqNeyBFea2tSREXej.eKWO5Egk3pbCcoV.fRcSeEEOqRGWq	1	Adriano	Sergi	1990-01-01	\N	\N	\N	admin	1	0
\.


--
-- Name: allenatori_id_seq; Type: SEQUENCE SET; Schema: public; Owner: registro_user
--

SELECT pg_catalog.setval('public.allenatori_id_seq', 1, false);


--
-- Name: categorie_id_seq; Type: SEQUENCE SET; Schema: public; Owner: registro_user
--

SELECT pg_catalog.setval('public.categorie_id_seq', 14, true);


--
-- Name: convocazione_gare_id_seq; Type: SEQUENCE SET; Schema: public; Owner: registro_user
--

SELECT pg_catalog.setval('public.convocazione_gare_id_seq', 37, true);


--
-- Name: convocazione_giocatori_id_seq; Type: SEQUENCE SET; Schema: public; Owner: registro_user
--

SELECT pg_catalog.setval('public.convocazione_giocatori_id_seq', 1, false);


--
-- Name: convocazioni_id_seq; Type: SEQUENCE SET; Schema: public; Owner: registro_user
--

SELECT pg_catalog.setval('public.convocazioni_id_seq', 2, true);


--
-- Name: gruppi_id_seq; Type: SEQUENCE SET; Schema: public; Owner: registro_user
--

SELECT pg_catalog.setval('public.gruppi_id_seq', 8, true);


--
-- Name: persone_id_seq; Type: SEQUENCE SET; Schema: public; Owner: registro_user
--

SELECT pg_catalog.setval('public.persone_id_seq', 16, true);


--
-- Name: registro_id_seq; Type: SEQUENCE SET; Schema: public; Owner: registro_user
--

SELECT pg_catalog.setval('public.registro_id_seq', 46, true);


--
-- Name: societa_id_seq; Type: SEQUENCE SET; Schema: public; Owner: registro_user
--

SELECT pg_catalog.setval('public.societa_id_seq', 2, true);


--
-- Name: utente_categorie_id_seq; Type: SEQUENCE SET; Schema: public; Owner: registro_user
--

SELECT pg_catalog.setval('public.utente_categorie_id_seq', 10, true);


--
-- Name: utenti_id_seq; Type: SEQUENCE SET; Schema: public; Owner: registro_user
--

SELECT pg_catalog.setval('public.utenti_id_seq', 5, true);


--
-- Name: allenatori allenatori_pkey; Type: CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.allenatori
    ADD CONSTRAINT allenatori_pkey PRIMARY KEY (id);


--
-- Name: categorie categorie_pkey; Type: CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.categorie
    ADD CONSTRAINT categorie_pkey PRIMARY KEY (id);


--
-- Name: codici codici_pkey; Type: CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.codici
    ADD CONSTRAINT codici_pkey PRIMARY KEY (codice);


--
-- Name: convocazione_gare convocazione_gare_pkey; Type: CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.convocazione_gare
    ADD CONSTRAINT convocazione_gare_pkey PRIMARY KEY (id);


--
-- Name: convocazione_giocatori convocazione_giocatori_pkey; Type: CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.convocazione_giocatori
    ADD CONSTRAINT convocazione_giocatori_pkey PRIMARY KEY (id);


--
-- Name: convocazioni convocazioni_pkey; Type: CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.convocazioni
    ADD CONSTRAINT convocazioni_pkey PRIMARY KEY (id);


--
-- Name: gruppi gruppi_nome_key; Type: CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.gruppi
    ADD CONSTRAINT gruppi_nome_key UNIQUE (nome);


--
-- Name: gruppi gruppi_pkey; Type: CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.gruppi
    ADD CONSTRAINT gruppi_pkey PRIMARY KEY (id);


--
-- Name: persone persone_pkey; Type: CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.persone
    ADD CONSTRAINT persone_pkey PRIMARY KEY (id);


--
-- Name: registro registro_pkey; Type: CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.registro
    ADD CONSTRAINT registro_pkey PRIMARY KEY (id);


--
-- Name: societa societa_pkey; Type: CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.societa
    ADD CONSTRAINT societa_pkey PRIMARY KEY (id);


--
-- Name: utente_categorie utente_categorie_pkey; Type: CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.utente_categorie
    ADD CONSTRAINT utente_categorie_pkey PRIMARY KEY (id);


--
-- Name: utenti utenti_pkey; Type: CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.utenti
    ADD CONSTRAINT utenti_pkey PRIMARY KEY (id);


--
-- Name: utenti utenti_username_key; Type: CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.utenti
    ADD CONSTRAINT utenti_username_key UNIQUE (username);


--
-- Name: categorie categorie_societa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.categorie
    ADD CONSTRAINT categorie_societa_id_fkey FOREIGN KEY (societa_id) REFERENCES public.societa(id);


--
-- Name: convocazione_gare convocazione_gare_convocazione_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.convocazione_gare
    ADD CONSTRAINT convocazione_gare_convocazione_id_fkey FOREIGN KEY (convocazione_id) REFERENCES public.convocazioni(id) ON DELETE CASCADE;


--
-- Name: convocazione_giocatori convocazione_giocatori_gara_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.convocazione_giocatori
    ADD CONSTRAINT convocazione_giocatori_gara_id_fkey FOREIGN KEY (gara_id) REFERENCES public.convocazione_gare(id) ON DELETE CASCADE;


--
-- Name: convocazione_giocatori convocazione_giocatori_persona_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.convocazione_giocatori
    ADD CONSTRAINT convocazione_giocatori_persona_id_fkey FOREIGN KEY (persona_id) REFERENCES public.persone(id) ON DELETE CASCADE;


--
-- Name: convocazioni convocazioni_categoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.convocazioni
    ADD CONSTRAINT convocazioni_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorie(id) ON DELETE CASCADE;


--
-- Name: convocazioni convocazioni_societa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.convocazioni
    ADD CONSTRAINT convocazioni_societa_id_fkey FOREIGN KEY (societa_id) REFERENCES public.societa(id);


--
-- Name: persone persone_categoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.persone
    ADD CONSTRAINT persone_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorie(id);


--
-- Name: persone persone_gruppo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.persone
    ADD CONSTRAINT persone_gruppo_id_fkey FOREIGN KEY (gruppo_id) REFERENCES public.gruppi(id);


--
-- Name: persone persone_societa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.persone
    ADD CONSTRAINT persone_societa_id_fkey FOREIGN KEY (societa_id) REFERENCES public.societa(id);


--
-- Name: registro registro_categoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.registro
    ADD CONSTRAINT registro_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorie(id);


--
-- Name: registro registro_codice_fkey; Type: FK CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.registro
    ADD CONSTRAINT registro_codice_fkey FOREIGN KEY (codice) REFERENCES public.codici(codice);


--
-- Name: registro registro_persona_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.registro
    ADD CONSTRAINT registro_persona_id_fkey FOREIGN KEY (persona_id) REFERENCES public.persone(id);


--
-- Name: registro registro_societa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.registro
    ADD CONSTRAINT registro_societa_id_fkey FOREIGN KEY (societa_id) REFERENCES public.societa(id);


--
-- Name: utente_categorie utente_categorie_categoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.utente_categorie
    ADD CONSTRAINT utente_categorie_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorie(id) ON DELETE CASCADE;


--
-- Name: utente_categorie utente_categorie_utente_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.utente_categorie
    ADD CONSTRAINT utente_categorie_utente_id_fkey FOREIGN KEY (utente_id) REFERENCES public.utenti(id) ON DELETE CASCADE;


--
-- Name: utenti utenti_societa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: registro_user
--

ALTER TABLE ONLY public.utenti
    ADD CONSTRAINT utenti_societa_id_fkey FOREIGN KEY (societa_id) REFERENCES public.societa(id);


--
-- PostgreSQL database dump complete
--

\unrestrict Xri38YcoTAyIokLB2bT0q4jK2vcp34oECQhyyEVLmQr089oWN7uJ8mH9HmLLzAZ

