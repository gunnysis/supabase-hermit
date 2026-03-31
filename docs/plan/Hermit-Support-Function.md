# 고립·운둔 청년 지능형 지원 시스템 (Hermit-Support-Hub)

> 작성일: 2026-04-01 | 상태: 설계 완료 (v6: 엔지니어링 및 데이터 파이프라인 최적화)

## 1. 아키텍처 개요 (System Architecture)

본 시스템은 외부 공공 API의 비정형 데이터를 수집하여 고립 청년 맞춤형으로 가공하고, 이를 고성능으로 서빙하기 위한 **ETL -> AI-Enrichment -> API Serving** 파이프라인을 따릅니다.

---

## 2. 데이터 인제스천 및 정규화 (Data Ingestion & Normalization)

### 2.1 멀티 어댑터 수집기 (Multi-Adapter Ingestor)
- **Engine**: Supabase Edge Functions (Deno Runtime)
- **Sources**: 
  - `YouthCenterAdapter`: XML to JSON 변환 및 `bizId` 추출.
  - `BokjiroAdapter`: 복지로 특유의 `srvId` 기반 수집 및 `category_code` 매핑.
  - `LocalGovScraper`: 지자체 고립 청년 특화 사업(RSS/JSON) 수집.
- **지역 코드 표준화**: 공공데이터의 다양한 지역 표기법을 **행정안전부 법정동 코드(5~10자리)**로 정규화하여 저장.

### 2.2 멱등성 및 변경 감지 (Idempotency & Change Detection)
- `raw_content_hash` 컬럼을 두어 API 응답의 해시값을 저장.
- 매일 배치 실행 시 해시값이 동일하면 LLM 가공(Summarization) 단계를 스킵하여 비용 최적화.

---

## 3. AI 파이프라인 및 임베딩 (AI Enrichment & Embedding)

### 3.1 단계별 LLM 프로세싱 (Tiered LLM Pipeline)
1.  **Stage 1 (Flash)**: `gemini-1.5-flash`를 사용하여 본문을 3줄 요약하고 카테고리 태그(10종) 자동 분류.
2.  **Stage 2 (Pro)**: `gemini-1.5-pro`를 사용하여 신청 절차의 복잡도를 분석, `psychological_threshold` (1~5) 점수 산출.
3.  **Stage 3 (Validation)**: 생성된 요약이 원문의 핵심 수혜 조건(소득, 연령 등)을 포함하는지 자가 검증.

### 3.2 벡터 검색 준비 (Future-proofing)
- 향후 시맨틱 검색을 위해 `summary_vector` (vector(768)) 컬럼을 예약하고, `text-embedding-004` 모델을 통한 벡터화 준비.

---

## 4. 데이터베이스 모델링 (Database Engineering)

### 4.1 `support_programs` 테이블 상세 스펙
```sql
CREATE TABLE support_programs (
  id BIGSERIAL PRIMARY KEY,
  source_type TEXT NOT NULL, -- 'youth_center' | 'bokjiro' | 'local'
  ext_id TEXT NOT NULL,
  title TEXT NOT NULL,
  content_raw TEXT, -- API 원문 (비정형)
  
  -- 정규화된 필드
  region_code TEXT, -- 5자리 법정동 코드 (시군구 단위)
  category_enum TEXT, -- [COUNSELING, ECONOMIC, HOUSING, SOCIAL, JOB]
  
  -- AI 가공 데이터 (Pre-computed)
  summary_json JSONB, -- { "summary": ["...", "..."], "first_step": "..." }
  threshold_score SMALLINT, -- 1~5
  warm_comment TEXT,
  
  -- 메타데이터
  apply_url TEXT,
  end_date DATE,
  is_active BOOLEAN DEFAULT true,
  content_hash TEXT, -- 변경 감지용
  
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  
  UNIQUE(source_type, ext_id)
);

-- 성능 최적화 인덱스
CREATE INDEX idx_support_search_vector ON support_programs USING gin (to_tsvector('simple', title || ' ' || content_raw));
CREATE INDEX idx_support_filter ON support_programs (region_code, category_enum, is_active);
```

---

## 5. 검색 및 추천 로직 (Search & Ranking)

### 5.1 하이브리드 랭킹 알고리즘
검색 결과 정렬 시 다음 가중치를 합산하여 `relevance_score`를 계산합니다.
- **FTS Score**: 검색어 매칭도 (30%)
- **Energy Match**: 유저의 현재 에너지 레벨과 `threshold_score`의 적합도 (40%)
- **Recency**: 게시일 및 마감 임박도 (20%)
- **Location**: 유저 지역과의 일치 여부 (10%)

---

## 6. 보안 및 인프라 (Security & Infrastructure)

### 6.1 API 관리 및 성능
- **Rate Limiting**: 공공 API 서버 부하 방지를 위해 요청당 1초 이상의 간격을 두는 지연 큐(Delayed Queue) 적용.
- **Cache Strategy**: Edge Runtime 수준에서 `stale-while-revalidate` 전략을 사용하여 조회 성능 극대화.
- **Secrets**: API 키 및 토큰은 Supabase Vault를 통해 환경 변수로 관리.

---

## 7. 구현 로드맵 (Technical Roadmap)

1.  **Phase 1: Ingestion Engine**
    - Deno 기반 Multi-Source Crawler 개발.
    - 정규화 로직 및 DB 스키마 구축.
2.  **Phase 2: AI Enrichment Pipe**
    - Gemini API 연동 및 비동기 배치 요약 로직 구축.
    - 해시 기반 변경 감지 시스템 적용.
3.  **Phase 3: Service Layer**
    - PostgreSQL Full-Text Search 및 하이브리드 랭킹 RPC 구현.
    - 앱/웹 통합 검색 UI 연동.
