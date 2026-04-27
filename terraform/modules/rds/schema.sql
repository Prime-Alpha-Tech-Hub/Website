-- ═══════════════════════════════════════════════════════════════════════════
--  PAS SaaS RDS Schema — PostgreSQL 15
--  30 tables across 9 logical domains
--  Run once on initial provisioning; idempotent (IF NOT EXISTS everywhere)
-- ═══════════════════════════════════════════════════════════════════════════

-- ── Enable extensions ────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- gen_random_uuid()

-- ── Enum types ───────────────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE plan_type             AS ENUM ('starter','growth','enterprise');
  EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TYPE subscription_status   AS ENUM ('active','suspended','cancelled');
  EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TYPE user_role              AS ENUM ('owner','admin','pm','analyst','viewer');
  EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TYPE company_strategy       AS ENUM ('pe','private_credit','commodities','real_estate');
  EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TYPE company_access_status  AS ENUM ('active','suspended','demo');
  EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TYPE deal_stage             AS ENUM ('sourcing','screening','dd','ic_review','term_sheet','closing','closed_won','closed_lost');
  EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TYPE dd_checklist_status    AS ENUM ('pending','in_progress','complete');
  EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TYPE dd_file_type           AS ENUM ('pdf','docx','xlsx','image','other');
  EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TYPE dd_category            AS ENUM ('financial','legal','commercial','operational','esg','technical','other');
  EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TYPE risk_level             AS ENUM ('critical','high','medium','low','info');
  EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TYPE ic_memo_status         AS ENUM ('draft','submitted','approved','rejected','deferred');
  EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TYPE ic_vote_value          AS ENUM ('approve','reject','abstain','pending','request_info');
  EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TYPE limit_type             AS ENUM ('concentration','fx','leverage','var');
  EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TYPE investor_type          AS ENUM ('lp','family_office','institutional','sovereign');
  EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TYPE kyc_status             AS ENUM ('pending','approved','failed','expired');
  EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TYPE comm_channel           AS ENUM ('email','call','meeting','other');
  EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TYPE report_type            AS ENUM ('quarterly','annual','flash');
  EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  CREATE TYPE doc_action             AS ENUM ('view','download','share','edit');
  EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
--  DOMAIN 1 — Tenancy & Access (5 tables)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS tenants (
  tenant_id   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  firm_name   TEXT        NOT NULL,
  slug        TEXT        NOT NULL UNIQUE,
  region      TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS subscriptions (
  subscription_id UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID        NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  plan            plan_type   NOT NULL,
  status          subscription_status NOT NULL DEFAULT 'active',
  starts_at       DATE        NOT NULL,
  expires_at      DATE,
  revoked_at      TIMESTAMPTZ,
  revoked_by      UUID,                          -- soft ref to users, no FK constraint
  notes           TEXT
);

CREATE TABLE IF NOT EXISTS tenant_users (
  tenant_user_id UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id      UUID        NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  email          TEXT        NOT NULL,
  name           TEXT,
  role           user_role   NOT NULL DEFAULT 'analyst',
  is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
  invited_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_login     TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS plan_features (
  feature_id     UUID       PRIMARY KEY DEFAULT gen_random_uuid(),
  plan           plan_type  NOT NULL,
  feature_key    TEXT       NOT NULL,
  enabled        BOOLEAN    NOT NULL DEFAULT TRUE,
  max_users      INT,
  max_deals      INT,
  max_documents  INT
);

-- ═══════════════════════════════════════════════════════════════════════════
--  DOMAIN 2 — Core Business (2 tables)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS companies (
  company_id    UUID                   PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     UUID                   REFERENCES tenants(tenant_id) ON DELETE SET NULL,
  name          TEXT                   NOT NULL,
  strategy      company_strategy,
  region        TEXT,
  is_demo       BOOLEAN                NOT NULL DEFAULT FALSE,
  access_status company_access_status  NOT NULL DEFAULT 'active',
  created_at    TIMESTAMPTZ            NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS users (
  user_id            UUID       PRIMARY KEY DEFAULT gen_random_uuid(),
  email              TEXT       NOT NULL UNIQUE,
  name               TEXT,
  role               user_role  NOT NULL DEFAULT 'analyst',
  can_manage_tenants BOOLEAN    NOT NULL DEFAULT FALSE,
  is_active          BOOLEAN    NOT NULL DEFAULT TRUE
);

-- ── Memberships (cross-tenant user ↔ company mapping) ───────────────────────
CREATE TABLE IF NOT EXISTS memberships (
  membership_id  UUID       PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id      UUID       REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  tenant_user_id UUID       REFERENCES tenant_users(tenant_user_id) ON DELETE CASCADE,
  company_id     UUID       NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
  role           user_role  NOT NULL DEFAULT 'analyst',
  granted_by     UUID                   -- PAS staff user, soft ref
);

-- ═══════════════════════════════════════════════════════════════════════════
--  DOMAIN 3 — Deal Management (5 tables)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS deals (
  deal_id     UUID             PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id  UUID             NOT NULL REFERENCES companies(company_id) ON DELETE CASCADE,
  assigned_to UUID             REFERENCES users(user_id) ON DELETE SET NULL,
  strategy    company_strategy NOT NULL,
  stage       deal_stage       NOT NULL DEFAULT 'sourcing',
  deal_size   NUMERIC(20,6),
  currency    TEXT             NOT NULL DEFAULT 'USD',
  created_at  TIMESTAMPTZ      NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS deal_notes (
  note_id    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id    UUID        NOT NULL REFERENCES deals(deal_id) ON DELETE CASCADE,
  user_id    UUID        REFERENCES users(user_id) ON DELETE SET NULL,
  body       TEXT        NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS stage_history (
  history_id UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id    UUID        NOT NULL REFERENCES deals(deal_id) ON DELETE CASCADE,
  changed_by UUID        REFERENCES users(user_id) ON DELETE SET NULL,
  from_stage deal_stage,
  to_stage   deal_stage  NOT NULL,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS deal_scores (
  score_id  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id   UUID        NOT NULL REFERENCES deals(deal_id) ON DELETE CASCADE,
  score     NUMERIC(5,2),
  criteria  JSONB,
  scored_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS activity_log (
  log_id     UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID        REFERENCES users(user_id) ON DELETE SET NULL,
  company_id UUID        REFERENCES companies(company_id) ON DELETE CASCADE,
  action     TEXT        NOT NULL,
  ref_table  TEXT,
  ref_id     UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════════════════
--  DOMAIN 4 — Due Diligence (3 tables)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS dd_checklists (
  checklist_id UUID                  PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id      UUID                  NOT NULL REFERENCES deals(deal_id) ON DELETE CASCADE,
  status       dd_checklist_status   NOT NULL DEFAULT 'pending',
  created_at   TIMESTAMPTZ           NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS dd_documents (
  doc_id       UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  checklist_id UUID         REFERENCES dd_checklists(checklist_id) ON DELETE CASCADE,
  deal_id      UUID         REFERENCES deals(deal_id) ON DELETE CASCADE,
  uploaded_by  UUID         REFERENCES users(user_id) ON DELETE SET NULL,
  s3_url       TEXT,
  file_type    dd_file_type,
  category     dd_category
);

CREATE TABLE IF NOT EXISTS dd_findings (
  finding_id    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  checklist_id  UUID        REFERENCES dd_checklists(checklist_id) ON DELETE CASCADE,
  report_s3_url TEXT,
  risk_level    risk_level  NOT NULL DEFAULT 'medium',
  summary       TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════════════════
--  DOMAIN 5 — Investment Committee (3 tables)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS ic_memos (
  memo_id     UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id     UUID            REFERENCES deals(deal_id) ON DELETE CASCADE,
  company_id  UUID            REFERENCES companies(company_id) ON DELETE CASCADE,
  author_id   UUID            REFERENCES users(user_id) ON DELETE SET NULL,
  memo_s3_url TEXT,
  status      ic_memo_status  NOT NULL DEFAULT 'draft',
  version     INT             NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS ic_votes (
  vote_id   UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  memo_id   UUID           NOT NULL REFERENCES ic_memos(memo_id) ON DELETE CASCADE,
  member_id UUID           REFERENCES users(user_id) ON DELETE SET NULL,
  vote      ic_vote_value  NOT NULL DEFAULT 'pending',
  rationale TEXT,
  voted_at  TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS ic_comments (
  comment_id UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  memo_id    UUID        NOT NULL REFERENCES ic_memos(memo_id) ON DELETE CASCADE,
  user_id    UUID        REFERENCES users(user_id) ON DELETE SET NULL,
  body       TEXT        NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════════════════
--  DOMAIN 6 — Portfolio Management (4 tables)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS positions (
  position_id UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id     UUID        REFERENCES deals(deal_id) ON DELETE SET NULL,
  company_id  UUID        REFERENCES companies(company_id) ON DELETE CASCADE,
  moic        NUMERIC(10,4),
  irr         NUMERIC(10,4),
  nav         NUMERIC(20,6),
  currency    TEXT        NOT NULL DEFAULT 'USD'
);

CREATE TABLE IF NOT EXISTS snapshots (
  snapshot_id UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  position_id UUID        NOT NULL REFERENCES positions(position_id) ON DELETE CASCADE,
  period_end  DATE        NOT NULL,
  nav         NUMERIC(20,6),
  moic        NUMERIC(10,4),
  irr         NUMERIC(10,4)
);

CREATE TABLE IF NOT EXISTS risk_snapshots (
  risk_id       UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  position_id   UUID        REFERENCES positions(position_id) ON DELETE CASCADE,
  company_id    UUID        REFERENCES companies(company_id) ON DELETE CASCADE,
  var           NUMERIC(20,6),
  fx_exposure   NUMERIC(20,6),
  concentration NUMERIC(10,4),
  snapped_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS risk_breaches (
  breach_id   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  position_id UUID        REFERENCES positions(position_id) ON DELETE CASCADE,
  limit_type  limit_type  NOT NULL,
  value       NUMERIC(20,6),
  threshold   NUMERIC(20,6),
  breached_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════════════════
--  DOMAIN 7 — Investor CRM (3 tables)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS investors (
  investor_id UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT          NOT NULL,
  type        investor_type NOT NULL,
  jurisdiction TEXT,
  kyc_status  kyc_status    NOT NULL DEFAULT 'pending'
);

CREATE TABLE IF NOT EXISTS commitments (
  commitment_id UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id   UUID        NOT NULL REFERENCES investors(investor_id) ON DELETE CASCADE,
  fund          TEXT        NOT NULL,
  amount        NUMERIC(20,6) NOT NULL,
  currency      TEXT        NOT NULL DEFAULT 'USD',
  committed_at  DATE
);

CREATE TABLE IF NOT EXISTS communications (
  comm_id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id       UUID         REFERENCES investors(investor_id) ON DELETE CASCADE,
  user_id           UUID         REFERENCES users(user_id) ON DELETE SET NULL,
  attachment_s3_url TEXT,
  channel           comm_channel NOT NULL DEFAULT 'email',
  summary           TEXT
);

-- ═══════════════════════════════════════════════════════════════════════════
--  DOMAIN 8 — Reporting (1 table)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS reports (
  report_id  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID        REFERENCES companies(company_id) ON DELETE CASCADE,
  pdf_s3_url TEXT,
  period     TEXT,
  type       report_type NOT NULL,
  sent_at    TIMESTAMPTZ
);

-- ═══════════════════════════════════════════════════════════════════════════
--  DOMAIN 9 — Document Management (3 tables) + Articles
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS documents (
  doc_id    UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id  UUID    REFERENCES users(user_id) ON DELETE SET NULL,
  deal_id   UUID    REFERENCES deals(deal_id) ON DELETE SET NULL,  -- nullable
  s3_url    TEXT,
  encrypted BOOLEAN NOT NULL DEFAULT FALSE,
  version   INT     NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS doc_versions (
  version_id  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  doc_id      UUID        NOT NULL REFERENCES documents(doc_id) ON DELETE CASCADE,
  uploaded_by UUID        REFERENCES users(user_id) ON DELETE SET NULL,
  s3_url      TEXT,
  version_no  INT         NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS doc_access_log (
  access_id   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  doc_id      UUID        REFERENCES documents(doc_id) ON DELETE CASCADE,
  user_id     UUID        REFERENCES users(user_id) ON DELETE SET NULL,
  action      doc_action  NOT NULL DEFAULT 'view',
  accessed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS articles (
  article_id        UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id         UUID    REFERENCES users(user_id) ON DELETE SET NULL,
  deal_id           UUID    REFERENCES deals(deal_id) ON DELETE SET NULL,  -- nullable
  attachment_s3_url TEXT,
  title             TEXT    NOT NULL,
  body              TEXT,
  tags              TEXT[]
);

-- ═══════════════════════════════════════════════════════════════════════════
--  Indexes — optimise common query patterns
-- ═══════════════════════════════════════════════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_subscriptions_tenant      ON subscriptions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tenant_users_tenant       ON tenant_users(tenant_id);
CREATE INDEX IF NOT EXISTS idx_companies_tenant          ON companies(tenant_id);
CREATE INDEX IF NOT EXISTS idx_memberships_company       ON memberships(company_id);
CREATE INDEX IF NOT EXISTS idx_memberships_tenant_user   ON memberships(tenant_user_id);
CREATE INDEX IF NOT EXISTS idx_deals_company             ON deals(company_id);
CREATE INDEX IF NOT EXISTS idx_deals_stage               ON deals(stage);
CREATE INDEX IF NOT EXISTS idx_deals_strategy            ON deals(strategy);
CREATE INDEX IF NOT EXISTS idx_deal_notes_deal           ON deal_notes(deal_id);
CREATE INDEX IF NOT EXISTS idx_stage_history_deal        ON stage_history(deal_id);
CREATE INDEX IF NOT EXISTS idx_deal_scores_deal          ON deal_scores(deal_id);
CREATE INDEX IF NOT EXISTS idx_dd_checklists_deal        ON dd_checklists(deal_id);
CREATE INDEX IF NOT EXISTS idx_dd_documents_checklist    ON dd_documents(checklist_id);
CREATE INDEX IF NOT EXISTS idx_dd_findings_checklist     ON dd_findings(checklist_id);
CREATE INDEX IF NOT EXISTS idx_ic_memos_deal             ON ic_memos(deal_id);
CREATE INDEX IF NOT EXISTS idx_ic_memos_status           ON ic_memos(status);
CREATE INDEX IF NOT EXISTS idx_ic_votes_memo             ON ic_votes(memo_id);
CREATE INDEX IF NOT EXISTS idx_positions_company         ON positions(company_id);
CREATE INDEX IF NOT EXISTS idx_snapshots_position        ON snapshots(position_id);
CREATE INDEX IF NOT EXISTS idx_risk_snapshots_position   ON risk_snapshots(position_id);
CREATE INDEX IF NOT EXISTS idx_risk_breaches_position    ON risk_breaches(position_id);
CREATE INDEX IF NOT EXISTS idx_commitments_investor      ON commitments(investor_id);
CREATE INDEX IF NOT EXISTS idx_communications_investor   ON communications(investor_id);
CREATE INDEX IF NOT EXISTS idx_reports_company           ON reports(company_id);
CREATE INDEX IF NOT EXISTS idx_documents_owner           ON documents(owner_id);
CREATE INDEX IF NOT EXISTS idx_doc_versions_doc          ON doc_versions(doc_id);
CREATE INDEX IF NOT EXISTS idx_doc_access_log_doc        ON doc_access_log(doc_id);
CREATE INDEX IF NOT EXISTS idx_activity_log_company      ON activity_log(company_id);
CREATE INDEX IF NOT EXISTS idx_activity_log_created      ON activity_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_articles_author           ON articles(author_id);
