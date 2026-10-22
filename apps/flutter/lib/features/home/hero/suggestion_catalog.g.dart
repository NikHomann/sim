// GENERATED CODE - DO NOT MODIFY BY HAND
// Source: generated/blocks.json (\$meta.templates), packages/deployment-config
// integration-metadata.ts and apps/sim/lib/oauth/oauth.ts at the upstream commit
// in docs/port/UPSTREAM_COMMIT. Regenerate with (from apps/flutter):
//   dart run tools/gen/main.dart --catalog-only
// ignore_for_file: type=lint

import 'package:sim_app/features/home/hero/suggestion_types.dart';

/// Every catalog template whose block is a public integration (`CANDIDATES`
/// minus the table starters, `suggested-actions.tsx:89-114`).
const List<SuggestionTemplate> suggestionTemplates = <SuggestionTemplate>[
  SuggestionTemplate(
    id: 'affinity-0',
    blockType: 'affinity',
    label: 'Affinity pipeline digest',
    prompt:
        'Build a workflow that runs every Monday, pages my Affinity deal list for every row with its stage, owner, and last interaction date, and posts a Slack summary of what moved, what is stalled, and what is closing this month.',
    iconId: 'brand/affinity-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'affinity-1',
    blockType: 'affinity',
    label: 'Affinity meeting note logger',
    prompt:
        'Create a workflow that finds yesterday’s Affinity meetings, reads the transcript of each one, writes a short summary as a note anchored to that meeting, and attaches it to the company and people who attended.',
    iconId: 'brand/affinity-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'affinity-2',
    blockType: 'affinity',
    label: 'Affinity warm intro finder',
    prompt:
        'Build an agent that takes a target company name, resolves it in Affinity, and reports who on my team can make an introduction — ranking relationships by interaction score and adding coworker and investor paths into the same company.',
    iconId: 'brand/affinity-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'affinity-3',
    blockType: 'affinity',
    label: 'Affinity deal stage sync',
    prompt:
        'Create a workflow that watches a table of deal decisions, looks up the matching Affinity list row, resolves the stage name to its dropdown option, and writes the new stage onto the row.',
    iconId: 'brand/affinity-icon',
    modules: <String>['tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'affinity-4',
    blockType: 'affinity',
    label: 'Affinity company enrichment',
    prompt:
        'Build a workflow that takes new companies from my accounts table, searches Affinity for each one, reads its enriched fields, and writes headcount, location, and category back onto both the Affinity record and the table row.',
    iconId: 'brand/affinity-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'affinity-5',
    blockType: 'affinity',
    label: 'Affinity stale deal reminders',
    prompt:
        'Create a scheduled workflow that finds Affinity deals with no interaction in 30 days, creates a follow-up reminder on each one with a specific next step, and emails the owner a list of what went quiet.',
    iconId: 'brand/affinity-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'affinity-6',
    blockType: 'affinity',
    label: 'Affinity semantic sourcing',
    prompt:
        'Build an agent that takes an investment thesis in plain language, runs a semantic search across my Affinity companies, and writes the best matches to a table with why each one fits and which list it already sits on.',
    iconId: 'brand/affinity-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'affinity-7',
    blockType: 'affinity',
    label: 'Affinity data room search',
    prompt:
        'Create a workflow that takes a diligence question, searches the notes and files attached to a company in Affinity, and answers with the passages it found and the note or file each one came from.',
    iconId: 'brand/affinity-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'affinity-8',
    blockType: 'affinity',
    label: 'Affinity warehouse delta sync',
    prompt:
        'Build a scheduled workflow that reads the Affinity field value change feed from the cursor it stored last run, applies every add, update, and delete to my table mirror, and saves the new cursor only after the whole page applied.',
    iconId: 'brand/affinity-icon',
    modules: <String>['scheduled', 'tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'agentmail-0',
    blockType: 'agentmail',
    label: 'AgentMail inbox-per-customer',
    prompt:
        'Build a workflow that creates a dedicated AgentMail inbox for every new customer account, configures the display name and labels, and writes the inbox address back to the customer record so all customer email is isolated and threaded.',
    iconId: 'brand/agent-mail-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'agentmail-1',
    blockType: 'agentmail',
    label: 'AgentMail support concierge',
    prompt:
        'Create a knowledge base from product docs and past resolutions, then build a scheduled workflow that polls an AgentMail inbox for new threads, drafts a contextual reply with citations, and either sends it or saves it as a draft based on confidence.',
    iconId: 'brand/agent-mail-icon',
    modules: <String>['knowledge-base', 'scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'agentmail-2',
    blockType: 'agentmail',
    label: 'AgentMail draft assistant',
    prompt:
        'Build a scheduled workflow that polls AgentMail threads, drafts a reply that matches my tone using my recent sent messages as reference, and updates the existing draft each time the thread receives a new message so the draft stays current.',
    iconId: 'brand/agent-mail-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'agentmail-3',
    blockType: 'agentmail',
    label: 'AgentMail label organizer',
    prompt:
        'Create a workflow that classifies new AgentMail messages by topic and customer tier, applies the matching thread labels, and moves threads with stale labels into archive labels on a weekly schedule.',
    iconId: 'brand/agent-mail-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'agentmail-4',
    blockType: 'agentmail',
    label: 'AgentMail + Loops support touch-points',
    prompt:
        'Create a scheduled workflow that polls AgentMail support threads and sends a Loops event for each customer milestone — first contact, resolved, escalated — so Loops can automate the right follow-up email based on real support outcomes.',
    iconId: 'brand/agent-mail-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'agentmail-5',
    blockType: 'agentmail',
    label: 'AgentMail outbound sequence sender',
    prompt:
        'Build a workflow that reads a prospects table, creates a personalized AgentMail draft per contact using their enriched profile, sends the message from a dedicated inbox, and logs the thread ID back to the row so replies can be tracked.',
    iconId: 'brand/agent-mail-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'agentmail-6',
    blockType: 'agentmail',
    label: 'AgentMail thread escalation router',
    prompt:
        'Create a scheduled workflow that polls AgentMail inboxes for new messages, detects urgent or negative threads with an agent, forwards the full thread to the on-call address, and posts a Slack alert so nothing high-priority sits unanswered.',
    iconId: 'brand/agent-mail-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'agentphone-0',
    blockType: 'agentphone',
    label: 'AgentPhone SMS support line',
    prompt:
        'Create a workflow that provisions an AgentPhone number, replies to inbound support texts with an agent that pulls answers from context, and logs each conversation to a support table.',
    iconId: 'brand/agent-phone-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'agentphone-1',
    blockType: 'agentphone',
    label: 'AgentPhone lead call + transcript scoring',
    prompt:
        'Build a workflow that places an outbound AgentPhone call to a new inbound lead, retrieves the call transcript afterward, scores qualification with an agent, and writes the result into HubSpot.',
    iconId: 'brand/agent-phone-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'agentphone-2',
    blockType: 'agentphone',
    label: 'AgentPhone post-call summary',
    prompt:
        'Create a workflow that runs after every AgentPhone call, summarizes the transcript with action items, and updates the linked Salesforce or HubSpot record with next steps.',
    iconId: 'brand/agent-phone-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'agentphone-3',
    blockType: 'agentphone',
    label: 'AgentPhone appointment reminder',
    prompt:
        'Build a workflow that reads upcoming Calendly bookings and sends an AgentPhone SMS reminder to each attendee, then texts a confirmation when they reply.',
    iconId: 'brand/agent-phone-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'agentphone-4',
    blockType: 'agentphone',
    label: 'AgentPhone NPS texter',
    prompt:
        'Create a scheduled workflow that texts recent customers an NPS survey over AgentPhone, reads their SMS replies, and writes structured ratings to a feedback table.',
    iconId: 'brand/agent-phone-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'agentphone-5',
    blockType: 'agentphone',
    label: 'AgentPhone collections reminder',
    prompt:
        'Build a workflow that picks up Stripe overdue invoices, sends a polite AgentPhone SMS payment reminder with the amount due, and reads the customer reply to update the invoice record.',
    iconId: 'brand/agent-phone-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'agentphone-6',
    blockType: 'agentphone',
    label: 'AgentPhone call-to-ticket logger',
    prompt:
        'Create a scheduled workflow that lists recent AgentPhone calls, pulls each transcript, and opens a Zendesk ticket summarizing the issue so no call goes untracked.',
    iconId: 'brand/agent-phone-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'agiloft-0',
    blockType: 'agiloft',
    label: 'Agiloft contract launcher',
    prompt:
        'Build a workflow that on a closed-won Salesforce opportunity creates an Agiloft contract record from the right template, fills key fields from the opportunity, and routes for legal review.',
    iconId: 'brand/agiloft-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'agiloft-1',
    blockType: 'agiloft',
    label: 'Agiloft clause analyzer',
    prompt:
        'Create a workflow that pulls Agiloft contracts on a schedule, extracts key clauses, writes deviations from the standard template to a legal review table.',
    iconId: 'brand/agiloft-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'agiloft-2',
    blockType: 'agiloft',
    label: 'Agiloft renewal tracker',
    prompt:
        'Build a scheduled workflow that finds Agiloft contracts with renewals due in the next 90 days, creates a renewal-prep task in the CRM, and emails the account owner.',
    iconId: 'brand/agiloft-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'agiloft-3',
    blockType: 'agiloft',
    label: 'Agiloft approval router',
    prompt:
        'Create a scheduled workflow that searches Agiloft for contracts needing approval, posts a Microsoft Teams adaptive card to the approver, captures the decision, and updates Agiloft.',
    iconId: 'brand/agiloft-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'agiloft-4',
    blockType: 'agiloft',
    label: 'Agiloft compliance audit',
    prompt:
        'Build a scheduled monthly workflow that audits Agiloft contracts against compliance requirements, flags missing clauses or expired terms, and writes a remediation backlog.',
    iconId: 'brand/agiloft-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'agiloft-5',
    blockType: 'agiloft',
    label: 'Agiloft DocuSign bridge',
    prompt:
        'Create a scheduled workflow that searches Agiloft for contracts marked ready-to-sign, creates a DocuSign envelope from the template, sends it, and writes the envelope ID back to Agiloft.',
    iconId: 'brand/agiloft-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'agiloft-6',
    blockType: 'agiloft',
    label: 'Agiloft + Linear ticket bridge',
    prompt:
        'Build a scheduled workflow that searches Agiloft for contracts flagged for engineering review and creates a Linear ticket with the contract context and a link, keeping status synced both ways.',
    iconId: 'brand/agiloft-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ahrefs-0',
    blockType: 'ahrefs',
    label: 'Ahrefs keyword tracker',
    prompt:
        'Create a scheduled weekly workflow that queries Ahrefs for ranking positions of my tracked keywords, logs the results into a tables-based SEO scorecard, and posts a Slack summary of gainers and losers.',
    iconId: 'brand/ahrefs-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ahrefs-1',
    blockType: 'ahrefs',
    label: 'Ahrefs competitor backlink monitor',
    prompt:
        'Build a scheduled workflow that pulls new Ahrefs referring domains for my competitors weekly, flags high-authority links, and posts a Slack digest with the linking page and anchor text.',
    iconId: 'brand/ahrefs-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ahrefs-2',
    blockType: 'ahrefs',
    label: 'Ahrefs content gap finder',
    prompt:
        'Create a workflow that pulls Ahrefs organic keywords for both my domain and a competitor, has an agent diff the lists to find keywords the competitor ranks for that I do not, and writes a prioritized content brief table.',
    iconId: 'brand/ahrefs-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ahrefs-3',
    blockType: 'ahrefs',
    label: 'Ahrefs broken-link sweeper',
    prompt:
        'Build a scheduled workflow that runs an Ahrefs broken-backlinks check weekly, writes broken referring pages to a remediation table, and proposes redirects for the SEO lead to approve.',
    iconId: 'brand/ahrefs-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ahrefs-4',
    blockType: 'ahrefs',
    label: 'Ahrefs organic competitor finder',
    prompt:
        'Build a monthly workflow that pulls Ahrefs organic competitors for my domain, cross-references them against my tracked competitor list, and posts newly surfaced competitors to Slack for review.',
    iconId: 'brand/ahrefs-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ahrefs-5',
    blockType: 'ahrefs',
    label: 'Ahrefs + Similarweb growth scoreboard',
    prompt:
        'Build a scheduled monthly workflow that joins Ahrefs SEO data with Similarweb traffic intelligence, writes a growth scoreboard table, and emails leadership.',
    iconId: 'brand/ahrefs-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ahrefs-6',
    blockType: 'ahrefs',
    label: 'Ahrefs + Profound combined visibility',
    prompt:
        'Create a scheduled weekly workflow that combines Ahrefs SEO rankings with Profound AI-visibility scores, writes a combined visibility report, and surfaces gaps to Slack.',
    iconId: 'brand/ahrefs-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ahrefs-7',
    blockType: 'ahrefs',
    label: 'Ahrefs domain-health watchdog',
    prompt:
        'Build a scheduled workflow that checks Ahrefs domain rating and backlink stats for my site daily, logs the values to a trend table, and posts a Slack alert when domain rating drops or a spike of lost referring domains is detected.',
    iconId: 'brand/ahrefs-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ahrefs-8',
    blockType: 'ahrefs',
    label: 'Ahrefs Rank Tracker daily digest',
    prompt:
        'Build a scheduled daily workflow that pulls the Ahrefs Rank Tracker overview for my project, has an agent summarize position and traffic movers, and posts the digest to Slack.',
    iconId: 'brand/ahrefs-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ahrefs-9',
    blockType: 'ahrefs',
    label: 'Ahrefs batch competitor snapshot',
    prompt:
        'Create a workflow that runs an Ahrefs batch analysis across a list of competitor domains, writes the resulting Domain Rating, backlinks, and organic traffic to a comparison table, and has an agent call out the biggest gaps.',
    iconId: 'brand/ahrefs-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ahrefs-10',
    blockType: 'ahrefs',
    label: 'Ahrefs Site Audit issue tracker',
    prompt:
        'Build a scheduled weekly workflow that pulls crawled pages from an Ahrefs Site Audit project, writes non-compliant or broken pages to a remediation table, and posts a Slack summary for the SEO lead.',
    iconId: 'brand/ahrefs-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'airtable-0',
    blockType: 'airtable',
    label: 'Airtable data sync',
    prompt:
        'Create a scheduled workflow that syncs records from my Airtable base into a Sim table every hour, keeping both in sync. Use an agent to detect changes, resolve conflicts, and flag any discrepancies for review in Slack.',
    iconId: 'brand/airtable-icon',
    modules: <String>['tables', 'scheduled', 'agent', 'workflows'],
    providerId: 'airtable',
  ),
  SuggestionTemplate(
    id: 'airtable-1',
    blockType: 'airtable',
    label: 'Airtable two-way sync',
    prompt:
        'Build a scheduled workflow that mirrors records between an Airtable base and a Sim table, detects conflicts, and pings Slack on records that need manual resolution.',
    iconId: 'brand/airtable-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'airtable',
  ),
  SuggestionTemplate(
    id: 'airtable-2',
    blockType: 'airtable',
    label: 'Airtable form-to-CRM',
    prompt:
        'Create a workflow that watches Airtable form submissions, enriches each row with company data, and pushes qualifying leads into HubSpot with the right owner.',
    iconId: 'brand/airtable-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'airtable',
  ),
  SuggestionTemplate(
    id: 'airtable-3',
    blockType: 'airtable',
    label: 'Airtable content calendar publisher',
    prompt:
        'Build a workflow that reads an Airtable content calendar, publishes due posts to WordPress with proper formatting, and writes the live URL back to the row.',
    iconId: 'brand/airtable-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'airtable',
  ),
  SuggestionTemplate(
    id: 'airtable-4',
    blockType: 'airtable',
    label: 'Airtable approval workflow',
    prompt:
        'Create a workflow that watches Airtable for new approval rows, posts a Slack message with quick-action buttons, captures the decision, and updates the row state.',
    iconId: 'brand/airtable-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'airtable',
  ),
  SuggestionTemplate(
    id: 'airtable-5',
    blockType: 'airtable',
    label: 'Airtable digest reporter',
    prompt:
        'Build a scheduled weekly workflow that summarizes activity in a chosen Airtable base — new rows, status changes, completed items — and emails a digest to the project owner.',
    iconId: 'brand/airtable-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'airtable',
  ),
  SuggestionTemplate(
    id: 'airtable-6',
    blockType: 'airtable',
    label: 'Airtable to data-warehouse sync',
    prompt:
        'Create a scheduled workflow that exports an Airtable base to BigQuery nightly with schema mapping, partitions by ingestion date, and writes the run history to a control table.',
    iconId: 'brand/airtable-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'airtable',
  ),
  SuggestionTemplate(
    id: 'airtable-7',
    blockType: 'airtable',
    label: 'Trigger Gmail from Airtable records',
    prompt:
        'Build a workflow that watches Airtable for new or updated records and sends a personalised Gmail message for each one, so outreach and follow-ups go out automatically.',
    iconId: 'brand/airtable-icon',
    modules: <String>['agent', 'workflows'],
    featured: true,
    providerId: 'airtable',
  ),
  SuggestionTemplate(
    id: 'algolia-0',
    blockType: 'algolia',
    label: 'Algolia content indexer',
    prompt:
        'Build a workflow that watches a content source — WordPress, knowledge base — and upserts records into an Algolia index, removing deleted items for accurate search.',
    iconId: 'brand/algolia-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'algolia-1',
    blockType: 'algolia',
    label: 'Algolia search-quality auditor',
    prompt:
        'Create a scheduled workflow that runs benchmark queries against an Algolia index weekly, scores top-result relevance, and writes a quality report.',
    iconId: 'brand/algolia-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'algolia-2',
    blockType: 'algolia',
    label: 'Algolia settings tuner',
    prompt:
        'Build a workflow that reads an Algolia index settings, has an agent propose improvements to searchable attributes and ranking, and applies the approved settings update.',
    iconId: 'brand/algolia-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'algolia-3',
    blockType: 'algolia',
    label: 'Algolia index reconciler',
    prompt:
        'Create a workflow that browses all records in an Algolia index, compares them against a source-of-truth table, and batches adds, updates, and deletes to keep the index accurate.',
    iconId: 'brand/algolia-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'algolia-4',
    blockType: 'algolia',
    label: 'Algolia + knowledge base sync',
    prompt:
        'Build a workflow that mirrors a Sim knowledge base into an Algolia index, keeping vector retrieval and keyword search aligned for hybrid retrieval.',
    iconId: 'brand/algolia-icon',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'algolia-5',
    blockType: 'algolia',
    label: 'Algolia index inventory',
    prompt:
        'Create a scheduled workflow that lists all Algolia indices and their record counts, writes a daily inventory snapshot to a table, and pings on-call in Slack when an index record count drops unexpectedly.',
    iconId: 'brand/algolia-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'algolia-6',
    blockType: 'algolia',
    label: 'Algolia stale-record sweeper',
    prompt:
        'Build a scheduled workflow that browses an Algolia index, flags records older than a freshness threshold, writes them to a cleanup table, and deletes the confirmed stale records.',
    iconId: 'brand/algolia-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'amplitude-0',
    blockType: 'amplitude',
    label: 'Amplitude product analytics digest',
    prompt:
        'Create a scheduled weekly workflow that pulls key product metrics from Amplitude — active users, event segmentation for top events, and revenue — generates an executive summary with week-over-week trends, and posts it to Slack.',
    iconId: 'brand/amplitude-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'amplitude-1',
    blockType: 'amplitude',
    label: 'Amplitude event regression watcher',
    prompt:
        'Build a scheduled workflow that runs event segmentation on key Amplitude events every morning, compares the counts against the trailing 14-day baseline, and posts a Slack alert when any event drops more than a configurable threshold.',
    iconId: 'brand/amplitude-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'amplitude-2',
    blockType: 'amplitude',
    label: 'Amplitude active-user tracker',
    prompt:
        'Create a scheduled workflow that pulls daily and monthly active users from Amplitude, writes the values into a tracking table, and feeds the trend to downstream marketing automations.',
    iconId: 'brand/amplitude-icon',
    modules: <String>['tables', 'scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'amplitude-3',
    blockType: 'amplitude',
    label: 'Amplitude revenue digest',
    prompt:
        'Build a scheduled weekly workflow that pulls Amplitude revenue data, breaks it down by week-over-week change, and posts a digest to the product Slack channel.',
    iconId: 'brand/amplitude-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'amplitude-4',
    blockType: 'amplitude',
    label: 'Amplitude + PostHog cross-tool dashboard',
    prompt:
        'Build a scheduled workflow that aggregates equivalent active-user and event metrics from both Amplitude and PostHog, writes a side-by-side comparison to a table, and surfaces discrepancies to the product team in Slack.',
    iconId: 'brand/amplitude-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'amplitude-5',
    blockType: 'amplitude',
    label: 'Amplitude + Fathom unified analytics',
    prompt:
        'Build a scheduled workflow that joins Amplitude product analytics with Fathom web analytics, writes a unified active-user and engagement report, and surfaces anomalies.',
    iconId: 'brand/amplitude-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'amplitude-6',
    blockType: 'amplitude',
    label: 'Amplitude + Hex deep-dive notebook',
    prompt:
        'Create a workflow that triggers a Hex deep-dive notebook when an Amplitude metric crosses an anomaly threshold, runs analysis, and posts the notebook output to Slack.',
    iconId: 'brand/amplitude-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'apify-0',
    blockType: 'apify',
    label: 'Apify scraper orchestrator',
    prompt:
        'Build a workflow that triggers Apify scrapers on a schedule, captures the output, transforms into structured rows, and writes them to a downstream Sim table.',
    iconId: 'brand/apify-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'apify-1',
    blockType: 'apify',
    label: 'Apify lead-list builder',
    prompt:
        'Create a workflow that runs an Apify scraper on a target site, enriches each row with Clay, and writes the enriched lead list into HubSpot.',
    iconId: 'brand/apify-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'apify-2',
    blockType: 'apify',
    label: 'Apify monitor digest',
    prompt:
        'Build a scheduled workflow that watches an Apify actor’s runs for failures, captures error patterns, and posts a digest to engineering Slack.',
    iconId: 'brand/apify-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'apify-3',
    blockType: 'apify',
    label: 'Apify ecommerce price tracker',
    prompt:
        'Create a workflow that uses Apify scrapers to capture competitor pricing daily, writes the price history to a table, and posts price-drop alerts to Slack.',
    iconId: 'brand/apify-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'apify-4',
    blockType: 'apify',
    label: 'Apify event-data collector',
    prompt:
        'Build a workflow that uses Apify to scrape event sites — speakers, agendas, sponsors — and writes the data into a target-events research table.',
    iconId: 'brand/apify-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'apify-5',
    blockType: 'apify',
    label: 'Apify directory scraper',
    prompt:
        'Create a workflow that runs an Apify directory scraper, captures business listings, enriches via Hunter or Apollo, and writes the prospect list to a CRM-ready table.',
    iconId: 'brand/apify-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'apify-6',
    blockType: 'apify',
    label: 'Apify job-listing monitor',
    prompt:
        'Build a scheduled workflow that uses Apify to scrape job sites for tracked companies, flags new role types, and writes intel into a sales-research table.',
    iconId: 'brand/apify-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'apollo-0',
    blockType: 'apollo',
    label: 'Apollo lead enrichment',
    prompt:
        'Build a workflow that watches my leads table for new entries, enriches each lead with company size, funding, tech stack, and decision-maker contacts using Apollo and web search, then updates the table with the enriched information.',
    iconId: 'emcn/users',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'apollo-1',
    blockType: 'apollo',
    label: 'Apollo prospect researcher',
    prompt:
        'Create an agent that takes a company name, deep-researches them across the web and Apollo, finds key decision-makers, recent news, funding rounds, and pain points, then compiles a prospect brief I can review before outreach.',
    iconId: 'brand/apollo-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'apollo-2',
    blockType: 'apollo',
    label: 'Apollo ICP account builder',
    prompt:
        'Build a workflow that runs an Apollo organization search for accounts matching my ideal customer profile — industry, headcount, and tech stack — creates each as an Apollo account, and writes the new target list to a table for the SDR team.',
    iconId: 'brand/apollo-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'apollo-3',
    blockType: 'apollo',
    label: 'Apollo buying committee mapper',
    prompt:
        'Create a workflow that takes a target account, runs an Apollo people search across the relevant titles, enriches each contact with verified email and role, and writes a mapped buying committee to a table so reps know exactly who to engage.',
    iconId: 'emcn/users',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'apollo-4',
    blockType: 'apollo',
    label: 'Apollo enrichment to HubSpot',
    prompt:
        'Build a workflow that on a new inbound signup enriches the person and their company with Apollo, scores fit against my ICP, and creates or updates the matching contact and company in HubSpot with the enriched fields.',
    iconId: 'brand/apollo-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'apollo-5',
    blockType: 'apollo',
    label: 'Apollo pipeline tracker',
    prompt:
        'Create a scheduled workflow that searches Apollo opportunities by stage, summarizes new and at-risk deals with an agent, logs the snapshot to a pipeline table, and posts a daily deal-movement digest to the sales Slack channel.',
    iconId: 'brand/apollo-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'apollo-6',
    blockType: 'apollo',
    label: 'Apollo contact freshness sweep',
    prompt:
        'Build a scheduled workflow that pulls contacts from my CRM, bulk-enriches them through Apollo to refresh titles, emails, and company data, and bulk-updates the records so the database stays accurate for outbound.',
    iconId: 'emcn/users',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'appconfig-0',
    blockType: 'appconfig',
    label: 'AppConfig runtime config loader',
    prompt:
        'Build a workflow that retrieves the latest deployed AWS AppConfig configuration for a given application, environment, and profile, parses the JSON, and uses the feature flags to branch downstream agent behavior.',
    iconId: 'brand/app-config-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'appconfig-1',
    blockType: 'appconfig',
    label: 'AppConfig feature-flag publisher',
    prompt:
        'Create a workflow that takes a JSON feature-flag document, creates a new hosted configuration version in an AWS AppConfig configuration profile, and starts a deployment to the target environment using a chosen deployment strategy.',
    iconId: 'brand/app-config-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'appconfig-2',
    blockType: 'appconfig',
    label: 'AppConfig deployment monitor',
    prompt:
        'Build a scheduled workflow that lists in-progress AWS AppConfig deployments for an environment, gets each deployment status, and posts a Slack alert when a deployment is rolling back or has stalled.',
    iconId: 'brand/app-config-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'appconfig-3',
    blockType: 'appconfig',
    label: 'AppConfig config inventory',
    prompt:
        'Create a scheduled workflow that lists every AWS AppConfig application, its environments, and its configuration profiles, and writes a unified inventory into a tracking table so the platform team has a single source of truth.',
    iconId: 'brand/app-config-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'appconfig-4',
    blockType: 'appconfig',
    label: 'AppConfig change auditor',
    prompt:
        'Build a scheduled workflow that lists recent AWS AppConfig deployments across environments, summarizes which configuration versions were deployed when, and writes an audit report file for compliance review.',
    iconId: 'brand/app-config-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'appconfig-5',
    blockType: 'appconfig',
    label: 'AppConfig drift checker',
    prompt:
        'Create a scheduled workflow that retrieves the live AWS AppConfig configuration and compares it against an expected baseline stored in a table, alerting Slack when the deployed configuration drifts from the approved version.',
    iconId: 'brand/app-config-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'appconfig-6',
    blockType: 'appconfig',
    label: 'AppConfig bootstrap from GitHub',
    prompt:
        'Build a workflow triggered when a config file changes in a GitHub pull request that creates a new hosted AWS AppConfig configuration version from the file contents and deploys it to a staging environment for validation.',
    iconId: 'brand/app-config-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'appconfig-7',
    blockType: 'appconfig',
    label: 'AppConfig gated rollout',
    prompt:
        'Create a workflow that gates an AWS AppConfig deployment behind a Slack approval: it creates the configuration version, waits for sign-off, starts the deployment with a linear strategy, and monitors completion before reporting back.',
    iconId: 'brand/app-config-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'arxiv-0',
    blockType: 'arxiv',
    label: 'ArXiv paper alerter',
    prompt:
        'Build a scheduled workflow that queries ArXiv for new papers on tracked topics, summarizes abstracts with an agent, and emails the digest to the research team.',
    iconId: 'brand/arxiv-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'arxiv-1',
    blockType: 'arxiv',
    label: 'ArXiv literature review builder',
    prompt:
        'Create a workflow that takes a research topic, queries ArXiv for the most cited recent papers, summarizes each, and writes a literature review file.',
    iconId: 'brand/arxiv-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'arxiv-2',
    blockType: 'arxiv',
    label: 'ArXiv knowledge-base feeder',
    prompt:
        'Build a scheduled workflow that polls ArXiv for new papers in a topic, fetches PDFs, parses with Mistral Parser, and upserts the chunks into a research knowledge base.',
    iconId: 'brand/arxiv-icon',
    modules: <String>['knowledge-base', 'scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'arxiv-3',
    blockType: 'arxiv',
    label: 'ArXiv top-author tracker',
    prompt:
        'Create a scheduled workflow that monitors ArXiv for new papers by tracked authors and posts a Slack alert when a watched author publishes new work.',
    iconId: 'brand/arxiv-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'arxiv-4',
    blockType: 'arxiv',
    label: 'ArXiv weekly digest',
    prompt:
        'Build a scheduled weekly workflow that gathers the top ArXiv papers per tracked category, clusters them by theme, and writes a digest file.',
    iconId: 'brand/arxiv-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'arxiv-5',
    blockType: 'arxiv',
    label: 'ArXiv author-topic grapher',
    prompt:
        'Create a workflow that for a chosen ArXiv topic pulls papers and their authors, builds a co-authorship and topic graph in Neo4j, and exposes a visualization for the research team.',
    iconId: 'brand/arxiv-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'arxiv-6',
    blockType: 'arxiv',
    label: 'ArXiv survey-paper generator',
    prompt:
        'Build a workflow that takes a topic, finds the most influential ArXiv papers, summarizes themes, and writes a survey-style file as a starting point for research.',
    iconId: 'brand/arxiv-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'asana-0',
    blockType: 'asana',
    label: 'Asana sprint planner',
    prompt:
        'Build a workflow that on Monday morning compiles uncompleted Asana tasks, rebalances against capacity, and posts the sprint plan to the team Slack channel.',
    iconId: 'brand/asana-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'asana',
  ),
  SuggestionTemplate(
    id: 'asana-1',
    blockType: 'asana',
    label: 'Asana stuck-task surfacer',
    prompt:
        'Create a scheduled workflow that finds Asana tasks with no progress for 5+ days, pings the assignee in Slack with a quick-action prompt, and updates the task status based on their answer.',
    iconId: 'brand/asana-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'asana',
  ),
  SuggestionTemplate(
    id: 'asana-2',
    blockType: 'asana',
    label: 'Asana cross-team blocker watcher',
    prompt:
        'Build a scheduled workflow that searches Asana for tasks tagged blocked, identifies the blocking team based on dependency metadata, and posts a request to the right channel in Slack.',
    iconId: 'brand/asana-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'asana',
  ),
  SuggestionTemplate(
    id: 'asana-3',
    blockType: 'asana',
    label: 'Asana onboarding task launcher',
    prompt:
        'Create a workflow that on a new Salesforce opportunity creates a customer-onboarding Asana task with the right assignee and due date, and writes the task link back to the opportunity.',
    iconId: 'brand/asana-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'asana',
  ),
  SuggestionTemplate(
    id: 'asana-4',
    blockType: 'asana',
    label: 'Asana weekly project digest',
    prompt:
        'Build a scheduled weekly workflow that summarizes Asana project progress — completed, in-progress, at-risk — and emails a status update to each project sponsor.',
    iconId: 'brand/asana-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'asana',
  ),
  SuggestionTemplate(
    id: 'asana-5',
    blockType: 'asana',
    label: 'Asana retro generator',
    prompt:
        'Create a workflow that pulls Asana tasks completed in a sprint, summarizes wins, blockers, and patterns, and writes a retro doc shared with the team via Slack.',
    iconId: 'brand/asana-icon',
    modules: <String>['agent', 'files', 'workflows'],
    providerId: 'asana',
  ),
  SuggestionTemplate(
    id: 'asana-6',
    blockType: 'asana',
    label: 'Asana bug intake triager',
    prompt:
        'Build a workflow that searches Asana for newly created tasks in the bug project, classifies each by severity and component with an agent, adds a triage comment, and creates a matching GitHub issue for engineering pickup.',
    iconId: 'brand/asana-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'asana',
  ),
  SuggestionTemplate(
    id: 'ashby-0',
    blockType: 'ashby',
    label: 'Ashby pipeline digest',
    prompt:
        'Build a scheduled daily workflow that lists open Ashby jobs, summarizes candidate counts per stage, flags applications stalled for more than five days, logs metrics to a tracking table, and Slacks hiring managers a personalized pipeline digest.',
    iconId: 'brand/ashby-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ashby-1',
    blockType: 'ashby',
    label: 'Resume to Ashby candidate',
    prompt:
        'Create a workflow that watches a folder of inbound resumes, extracts contact info and work history, deduplicates against existing Ashby candidates, creates new candidate records when needed, and tags them with the source job they applied through.',
    iconId: 'brand/ashby-icon',
    modules: <String>['files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ashby-2',
    blockType: 'ashby',
    label: 'Ashby interview note logger',
    prompt:
        'Build a workflow that runs after every interview is logged in your meeting tool, summarizes the transcript, scores the candidate against the job requirements, creates a structured note on the matching Ashby candidate, and notifies the hiring manager in Slack.',
    iconId: 'brand/ashby-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ashby-3',
    blockType: 'ashby',
    label: 'Ashby stage-change responder',
    prompt:
        'Create a workflow that detects when an Ashby application moves into a new stage, sends the candidate a stage-appropriate email, prepares the interviewer brief in a file, and updates a recruiting tracking table so coordinators always know who is next.',
    iconId: 'brand/ashby-icon',
    modules: <String>['tables', 'files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ashby-4',
    blockType: 'ashby',
    label: 'Ashby DEI snapshot',
    prompt:
        'Build a scheduled monthly workflow that pulls Ashby candidates, applications, and openings, computes funnel diversity metrics by stage, role, and source, and writes a confidential report file shared with people leadership and compliance.',
    iconId: 'brand/ashby-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ashby-5',
    blockType: 'ashby',
    label: 'Ashby candidate enricher',
    prompt:
        'Create a workflow that takes new Ashby candidates, researches each across LinkedIn and the web for relevant background, writes a structured profile summary onto the candidate as an Ashby note, and updates a recruiting table with research links.',
    iconId: 'brand/ashby-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ashby-6',
    blockType: 'ashby',
    label: 'Ashby offer-ready brief',
    prompt:
        'Build a workflow that runs when an Ashby application reaches the offer stage, gathers compensation benchmarks, interview feedback, and candidate priorities, drafts an offer brief file for the hiring manager, and Slacks the people team to start the offer process.',
    iconId: 'brand/ashby-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'athena-0',
    blockType: 'athena',
    label: 'Athena scheduled report runner',
    prompt:
        'Create a scheduled workflow that runs a saved AWS Athena query daily, writes the result rows to a Sim table, and posts a Slack summary of the top movers.',
    iconId: 'brand/athena-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'athena-1',
    blockType: 'athena',
    label: 'Athena S3 access audit',
    prompt:
        'Build a workflow that runs Athena queries against S3 access logs weekly, identifies unusual access patterns or new principals, and writes findings to a security audit table.',
    iconId: 'brand/athena-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'athena-2',
    blockType: 'athena',
    label: 'Athena cost-explorer query',
    prompt:
        'Build a scheduled workflow that runs Athena queries against AWS cost-and-usage reports daily, writes top cost movers per service to a table, and posts an anomaly digest to Slack.',
    iconId: 'brand/athena-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'athena-3',
    blockType: 'athena',
    label: 'Athena + Tinybird real-time bridge',
    prompt:
        'Build a workflow that combines historical Athena queries with realtime Tinybird endpoints into a unified reporting view, writes results to a dashboard table.',
    iconId: 'brand/athena-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'athena-4',
    blockType: 'athena',
    label: 'Athena + PostHog data-warehouse join',
    prompt:
        'Create a scheduled workflow that joins PostHog event exports with Athena historical data, computes funnel conversion across the join, and writes a daily report.',
    iconId: 'brand/athena-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'athena-5',
    blockType: 'athena',
    label: 'Athena ad-hoc query agent',
    prompt:
        'Build a Slack agent that translates natural-language analytics questions into safe AWS Athena queries, executes them, and returns the table answer with the query for review.',
    iconId: 'brand/athena-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'athena-6',
    blockType: 'athena',
    label: 'Athena weekly executive metrics',
    prompt:
        'Create a scheduled weekly workflow that runs a set of AWS Athena queries against the data lake for revenue, retention, and usage metrics, writes the results to a metrics table, and emails a formatted scorecard to leadership.',
    iconId: 'brand/athena-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'attio-0',
    blockType: 'attio',
    label: 'Attio enrichment pipeline',
    prompt:
        'Build a workflow that watches new Attio records, enriches each contact with company size, funding, and tech stack via Apollo, and writes the enriched fields back to Attio.',
    iconId: 'brand/attio-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'attio',
  ),
  SuggestionTemplate(
    id: 'attio-1',
    blockType: 'attio',
    label: 'Attio deal pipeline tracker',
    prompt:
        'Create a scheduled workflow that mirrors Attio deals into a Sim table, calculates pipeline velocity per stage, and posts a daily Slack summary of deals at risk.',
    iconId: 'brand/attio-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'attio',
  ),
  SuggestionTemplate(
    id: 'attio-2',
    blockType: 'attio',
    label: 'Attio email-to-record logger',
    prompt:
        'Build a workflow that watches Gmail for emails to or from Attio contacts, logs each as an interaction on the matching record, and creates a follow-up task if mentioned.',
    iconId: 'brand/attio-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'attio',
  ),
  SuggestionTemplate(
    id: 'attio-3',
    blockType: 'attio',
    label: 'Attio call-summary updater',
    prompt:
        'Create a workflow that runs after a Fireflies sales call, summarizes the transcript into a deal-ready summary, and updates the matching Attio deal record.',
    iconId: 'brand/attio-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'attio',
  ),
  SuggestionTemplate(
    id: 'attio-4',
    blockType: 'attio',
    label: 'Attio win/loss analyzer',
    prompt:
        'Build a scheduled monthly workflow that pulls closed Attio deals, analyzes patterns in wins vs losses, and writes an insights report file for the sales team.',
    iconId: 'brand/attio-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
    providerId: 'attio',
  ),
  SuggestionTemplate(
    id: 'attio-5',
    blockType: 'attio',
    label: 'Attio outreach orchestrator',
    prompt:
        'Create a workflow that watches Attio for contacts entering the outreach stage, drafts a personalized first-touch email, and queues it for the rep to review and send.',
    iconId: 'brand/attio-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'attio',
  ),
  SuggestionTemplate(
    id: 'attio-6',
    blockType: 'attio',
    label: 'Attio Slack channel-per-deal',
    prompt:
        'Build a workflow that for Attio deals above a threshold creates a Slack channel, invites the account team, and pins the deal record link.',
    iconId: 'brand/attio-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'attio',
  ),
  SuggestionTemplate(
    id: 'azure_data_explorer-0',
    blockType: 'azure_data_explorer',
    label: 'Ask questions of Kusto data',
    prompt:
        'Build an agent that turns plain-English questions about our telemetry into KQL, reads the Azure Data Explorer table schema first so the columns are real, runs the query, and answers with the numbers plus the query it used.',
    iconId: 'brand/azure-data-explorer-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'azure_data_explorer-1',
    blockType: 'azure_data_explorer',
    label: 'Daily telemetry digest',
    prompt:
        'Create a scheduled workflow that queries Azure Data Explorer every morning for yesterday error rates, latency percentiles, and traffic by service, summarizes what moved against the prior week, and posts the digest to our engineering Slack channel.',
    iconId: 'brand/azure-data-explorer-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'azure_data_explorer-2',
    blockType: 'azure_data_explorer',
    label: 'Kusto anomaly alerts',
    prompt:
        'Build a workflow that runs every 15 minutes, queries Azure Data Explorer for request failures grouped by endpoint, compares each endpoint against its own trailing baseline, and pages the on-call engineer through PagerDuty only when a real spike appears.',
    iconId: 'brand/azure-data-explorer-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'azure_data_explorer-3',
    blockType: 'azure_data_explorer',
    label: 'Incident timeline from telemetry',
    prompt:
        'Create a workflow that takes an incident window and service name, pulls the matching logs, traces, and deploy events out of Azure Data Explorer, and writes an ordered timeline file that an engineer can drop straight into a postmortem.',
    iconId: 'brand/azure-data-explorer-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'azure_data_explorer-4',
    blockType: 'azure_data_explorer',
    label: 'Event pipeline into Kusto',
    prompt:
        'Build a workflow triggered by a webhook that validates each incoming event payload, maps it onto our Azure Data Explorer table schema, ingests the rows inline, and records any rejected payloads in a table so nothing is lost silently.',
    iconId: 'brand/azure-data-explorer-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'azure_data_explorer-5',
    blockType: 'azure_data_explorer',
    label: 'Kusto cluster inventory',
    prompt:
        'Create a scheduled workflow that lists every Azure Data Explorer database and table, reads their schemas, and keeps a Sim table up to date as a searchable data-model catalog with a note on what changed since the last run.',
    iconId: 'brand/azure-data-explorer-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'azure_data_explorer-6',
    blockType: 'azure_data_explorer',
    label: 'Usage report to stakeholders',
    prompt:
        'Build a scheduled weekly workflow that queries Azure Data Explorer for product usage by account and feature, ranks the biggest movers, generates a report file with the supporting numbers, and emails it to the account team.',
    iconId: 'brand/azure-data-explorer-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'azure_devops-0',
    blockType: 'azure_devops',
    label: 'Azure DevOps build failure alerter',
    prompt:
        'Build a workflow triggered when an Azure DevOps build fails that fetches the build timeline and failing-stage logs, summarizes the root cause with an agent, and posts an actionable Slack alert with a deep link to the run.',
    iconId: 'brand/azure-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'azure_devops-1',
    blockType: 'azure_devops',
    label: 'Azure DevOps work-item triager',
    prompt:
        'Create a workflow triggered when an Azure DevOps work item is created that classifies it by type and priority, enriches the description, assigns the right area path, and posts a summary to the team channel.',
    iconId: 'brand/azure-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'azure_devops-2',
    blockType: 'azure_devops',
    label: 'Azure DevOps release notes generator',
    prompt:
        'Build a workflow that pulls the work items completed between two Azure DevOps builds, groups them by type with an agent, and writes formatted release notes to a file for the release manager.',
    iconId: 'brand/azure-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'azure_devops-3',
    blockType: 'azure_devops',
    label: 'Azure DevOps pipeline health report',
    prompt:
        'Create a scheduled daily workflow that lists Azure DevOps pipeline runs, computes pass rate and average duration per pipeline, logs them to a table for trend tracking, and Slacks a morning summary highlighting any regressions.',
    iconId: 'brand/azure-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'azure_devops-4',
    blockType: 'azure_devops',
    label: 'Azure DevOps to Linear bridge',
    prompt:
        'Build a workflow that watches new Azure DevOps work items, mirrors each as a Linear issue with full context and a back-link, and keeps the team aligned across both trackers.',
    iconId: 'brand/azure-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'azure_devops-5',
    blockType: 'azure_devops',
    label: 'Azure DevOps PR review summarizer',
    prompt:
        'Create a workflow triggered on a new Azure DevOps pull request that fetches the diff and linked work items, drafts a concise review summary and risk callouts with an agent, and posts it as a PR comment for reviewers.',
    iconId: 'brand/azure-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'azure_devops-6',
    blockType: 'azure_devops',
    label: 'Azure DevOps sprint burndown digest',
    prompt:
        'Build a scheduled daily workflow that queries Azure DevOps work items in the active sprint, computes remaining effort and at-risk items, logs the burndown to a table, and posts a morning summary to the team Slack channel.',
    iconId: 'brand/azure-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'bitbucket-0',
    blockType: 'bitbucket',
    label: 'Bitbucket pull request review assistant',
    prompt:
        'Build a workflow that reads a Bitbucket pull request, discovers its changed files with diffstat, reviews each bounded file diff against our engineering standards, and posts one concise general pull request comment with findings and suggested fixes.',
    iconId: 'brand/bitbucket-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'bitbucket',
  ),
  SuggestionTemplate(
    id: 'bitbucket-1',
    blockType: 'bitbucket',
    label: 'Bitbucket pipeline failure diagnosis',
    prompt:
        'Create a workflow that inspects a failed Bitbucket pipeline, lists its steps, reads the bounded tail of each failed step log, identifies the likely root cause, and sends an actionable diagnosis to Slack.',
    iconId: 'brand/bitbucket-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'bitbucket',
  ),
  SuggestionTemplate(
    id: 'bitbucket-2',
    blockType: 'bitbucket',
    label: 'Bitbucket merge readiness report',
    prompt:
        'Build a workflow that reads an open Bitbucket pull request, its reviewers, commit statuses, and changed-file summary, then reports approvals, failing checks, risky changes, and the remaining review work without merging it.',
    iconId: 'brand/bitbucket-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'bitbucket',
  ),
  SuggestionTemplate(
    id: 'bitbucket-3',
    blockType: 'bitbucket',
    label: 'Bitbucket release notes generator',
    prompt:
        'Create a workflow that lists recent Bitbucket commits in a repository, reads ambiguous commit details, groups the changes by area, and drafts clear release notes for review.',
    iconId: 'brand/bitbucket-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'bitbucket',
  ),
  SuggestionTemplate(
    id: 'bitbucket-4',
    blockType: 'bitbucket',
    label: 'Bitbucket stale pull request review',
    prompt:
        'Build a scheduled workflow that lists open Bitbucket pull requests, identifies stale work from its update timestamps and review state, summarizes the next action for each, and posts a weekly reminder in Slack.',
    iconId: 'brand/bitbucket-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'bitbucket',
  ),
  SuggestionTemplate(
    id: 'bitbucket-5',
    blockType: 'bitbucket',
    label: 'Bitbucket engineering activity digest',
    prompt:
        'Create a scheduled workflow that summarizes recent Bitbucket commits, pull request activity, and pipeline results across a repository into a concise engineering digest delivered by email.',
    iconId: 'brand/bitbucket-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'bitbucket',
  ),
  SuggestionTemplate(
    id: 'bitbucket-6',
    blockType: 'bitbucket',
    label: 'Bitbucket and Jira delivery automation',
    prompt:
        'Build a workflow that reads a Bitbucket pull request and its head commit, extracts Jira issue keys from the title, description, source branch, and commit message, summarizes delivery and pipeline status, and adds the update to the matching Jira issue.',
    iconId: 'brand/bitbucket-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'bitbucket',
  ),
  SuggestionTemplate(
    id: 'box-0',
    blockType: 'box',
    label: 'Box folder onboarding',
    prompt:
        'Create a workflow that watches a Box folder for new customer subfolders, applies the standard permissions matrix, seeds template files, and notifies the account owner.',
    iconId: 'brand/box-company-icon',
    modules: <String>['files', 'agent', 'workflows'],
    providerId: 'box',
  ),
  SuggestionTemplate(
    id: 'box-1',
    blockType: 'box',
    label: 'Box external-share auditor',
    prompt:
        'Build a scheduled weekly workflow that lists Box shared links shared with external collaborators, flags items above the sensitivity threshold, and writes a security review.',
    iconId: 'brand/box-company-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'box',
  ),
  SuggestionTemplate(
    id: 'box-2',
    blockType: 'box',
    label: 'Box compliance retention',
    prompt:
        'Create a scheduled workflow that finds Box documents past retention, applies legal hold or archives them, and writes the disposition record to an audit table.',
    iconId: 'brand/box-company-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'box',
  ),
  SuggestionTemplate(
    id: 'box-3',
    blockType: 'box',
    label: 'Box document Q&A agent',
    prompt:
        'Build an agent that indexes Box content into a knowledge base, answers user questions with sourced citations, and deploys as a chat endpoint for internal teams.',
    iconId: 'brand/box-company-icon',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
    providerId: 'box',
  ),
  SuggestionTemplate(
    id: 'box-4',
    blockType: 'box',
    label: 'Box to S3 backup',
    prompt:
        'Create a scheduled workflow that mirrors a Box folder tree into S3 nightly with incremental sync, captures the manifest, and pings Slack on any failed files.',
    iconId: 'brand/box-company-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'box',
  ),
  SuggestionTemplate(
    id: 'box-5',
    blockType: 'box',
    label: 'Box new-vendor folder setup',
    prompt:
        'Build a workflow triggered when a new vendor is created in a CRM that provisions a standard Box folder structure for that vendor, invites the right users, and writes the folder link to the vendor record.',
    iconId: 'brand/box-company-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'box',
  ),
  SuggestionTemplate(
    id: 'box-6',
    blockType: 'box',
    label: 'Box approval-flow router',
    prompt:
        'Create a workflow that watches a Box approval folder, posts a Slack request with quick-action buttons for each new doc, captures the decision, and labels the file accordingly.',
    iconId: 'brand/box-company-icon',
    modules: <String>['files', 'agent', 'workflows'],
    providerId: 'box',
  ),
  SuggestionTemplate(
    id: 'brandfetch-0',
    blockType: 'brandfetch',
    label: 'Brandfetch logo enricher',
    prompt:
        'Build a workflow that pulls company logos and brand colors from Brandfetch for each lead in a table, writes the asset URLs back, and uses them in personalized outreach.',
    iconId: 'brand/brandfetch-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'brandfetch-1',
    blockType: 'brandfetch',
    label: 'Brandfetch CRM enrichment',
    prompt:
        'Create a workflow that watches new HubSpot accounts, pulls Brandfetch data for each company domain, and writes brand colors and logo URLs to the company record.',
    iconId: 'brand/brandfetch-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'brandfetch-2',
    blockType: 'brandfetch',
    label: 'Brandfetch deck personalizer',
    prompt:
        'Build a workflow that on a new opportunity pulls the prospect’s brand assets from Brandfetch, generates a personalized pitch deck with their logo and colors, and attaches it.',
    iconId: 'brand/brandfetch-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'brandfetch-3',
    blockType: 'brandfetch',
    label: 'Brandfetch competitor logo collector',
    prompt:
        'Create a workflow that takes a list of competitor domains, pulls Brandfetch brand assets for each, and writes a competitive matrix file the marketing team can use.',
    iconId: 'brand/brandfetch-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'brandfetch-4',
    blockType: 'brandfetch',
    label: 'Brandfetch customer-portal personalizer',
    prompt:
        'Build a workflow that auto-themes a customer portal experience using Brandfetch brand colors for each new enterprise account.',
    iconId: 'brand/brandfetch-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'brandfetch-5',
    blockType: 'brandfetch',
    label: 'Brandfetch outbound enricher',
    prompt:
        'Create a workflow that enriches outbound prospect data with Brandfetch logos and brand metadata, and writes the enriched contact record to Email Bison for personalization.',
    iconId: 'brand/brandfetch-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'brandfetch-6',
    blockType: 'brandfetch',
    label: 'Brandfetch contract personalizer',
    prompt:
        'Build a workflow that pulls Brandfetch assets for the counterparty on a DocuSign envelope, embeds the right logo in the cover sheet, and sends.',
    iconId: 'brand/brandfetch-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'brex-0',
    blockType: 'brex',
    label: 'Brex receipt auto-attach',
    prompt:
        'Build a workflow that takes an uploaded receipt file and sends it to Brex with the Match Receipt operation so Brex automatically pairs it with the right card expense.',
    iconId: 'brand/brex-icon',
    modules: <String>['workflows', 'files'],
  ),
  SuggestionTemplate(
    id: 'brex-1',
    blockType: 'brex',
    label: 'Brex daily expense digest',
    prompt:
        'Build a scheduled workflow that runs every weekday morning, lists Brex expenses settled in the last 24 hours, summarizes total spend by merchant category, and posts the digest to a Slack channel.',
    iconId: 'brand/brex-icon',
    modules: <String>['workflows', 'scheduled'],
  ),
  SuggestionTemplate(
    id: 'brex-2',
    blockType: 'brex',
    label: 'Brex memo enforcer',
    prompt:
        'Build a scheduled workflow that lists approved Brex expenses, finds ones missing a memo, has an agent draft a memo from the merchant and amount details, and updates each expense with the drafted memo.',
    iconId: 'brand/brex-icon',
    modules: <String>['agent', 'workflows', 'scheduled'],
  ),
  SuggestionTemplate(
    id: 'brex-3',
    blockType: 'brex',
    label: 'Brex spend anomaly alert',
    prompt:
        'Build a scheduled workflow that lists recent Brex card transactions, flags any transaction above a configurable threshold, and emails the finance team a report of flagged transactions with merchant details.',
    iconId: 'brand/brex-icon',
    modules: <String>['workflows', 'scheduled'],
  ),
  SuggestionTemplate(
    id: 'brex-4',
    blockType: 'brex',
    label: 'Brex cash balance monitor',
    prompt:
        'Build a scheduled workflow that checks Brex cash account balances every morning and sends a Slack alert when the available balance of any account drops below a set threshold.',
    iconId: 'brand/brex-icon',
    modules: <String>['workflows', 'scheduled'],
  ),
  SuggestionTemplate(
    id: 'brex-5',
    blockType: 'brex',
    label: 'Brex budget utilization report',
    prompt:
        'Build a weekly workflow that lists Brex budgets and spend limits, computes utilization for each budget from its amount and current period balance, stores the results in a table, and emails a summary report.',
    iconId: 'brand/brex-icon',
    modules: <String>['workflows', 'scheduled', 'tables'],
  ),
  SuggestionTemplate(
    id: 'brex-6',
    blockType: 'brex',
    label: 'Brex approved-invoice payment automation',
    prompt:
        'Build a workflow that takes an approved invoice (vendor name, amount, and memo), creates the vendor in Brex if it does not already exist, and creates a transfer from the company cash account to pay it.',
    iconId: 'brand/brex-icon',
    modules: <String>['workflows'],
  ),
  SuggestionTemplate(
    id: 'brex-7',
    blockType: 'brex',
    label: 'Brex team directory assistant',
    prompt:
        'Build an agent that answers questions about company spend and team structure by looking up Brex users, departments, locations, and their expenses on demand.',
    iconId: 'brand/brex-icon',
    modules: <String>['agent'],
  ),
  SuggestionTemplate(
    id: 'brex-8',
    blockType: 'brex',
    label: 'Brex vendor payment tracker',
    prompt:
        'Build a workflow that lists Brex vendors and recent transfers, reconciles transfer statuses against expected payments stored in a table, and flags any failed or delayed payments.',
    iconId: 'brand/brex-icon',
    modules: <String>['workflows', 'tables'],
  ),
  SuggestionTemplate(
    id: 'brightdata-0',
    blockType: 'brightdata',
    label: 'Bright Data scraper orchestrator',
    prompt:
        'Build a workflow that uses Bright Data unblockers to scrape geo-restricted competitor pages, captures the data daily, and writes to a tracking table.',
    iconId: 'brand/bright-data-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'brightdata-1',
    blockType: 'brightdata',
    label: 'Bright Data competitor pricing',
    prompt:
        'Create a workflow that uses Bright Data to track competitor pricing across regions, captures geo-priced data, and posts notable price changes to Slack.',
    iconId: 'brand/bright-data-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'brightdata-2',
    blockType: 'brightdata',
    label: 'Bright Data SERP collector',
    prompt:
        'Build a scheduled workflow that uses Bright Data SERP scraping to capture rankings for tracked keywords across regions, and writes the results to an SEO scoreboard.',
    iconId: 'brand/bright-data-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'brightdata-3',
    blockType: 'brightdata',
    label: 'Bright Data review collector',
    prompt:
        'Create a workflow that uses Bright Data to scrape product reviews across geos, classifies sentiment, and writes findings into a product-feedback table.',
    iconId: 'brand/bright-data-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'brightdata-4',
    blockType: 'brightdata',
    label: 'Bright Data localization checker',
    prompt:
        'Build a scheduled workflow that uses Bright Data geo-targeted browsing to verify the brand’s site renders correctly in tracked regions, and writes findings to Slack.',
    iconId: 'brand/bright-data-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'brightdata-5',
    blockType: 'brightdata',
    label: 'Bright Data brand mention search',
    prompt:
        'Create a workflow that uses Bright Data to scrape mentions of the brand across global forums and review sites, writes mentions into a tracking table, and pings on spikes.',
    iconId: 'brand/bright-data-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'brightdata-6',
    blockType: 'brightdata',
    label: 'Bright Data inventory tracker',
    prompt:
        'Build a scheduled workflow that uses Bright Data to track competitor stock availability across regions, writes the data, and pings on low-stock signals indicating shifts.',
    iconId: 'brand/bright-data-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'browser_use-0',
    blockType: 'browser_use',
    label: 'Browser Use form filler',
    prompt:
        'Build a workflow that uses Browser Use to automate filling complex web forms — vendor portals, compliance questionnaires — with data pulled from a table, and captures screenshots to a file as audit trail.',
    iconId: 'brand/browser-use-icon',
    modules: <String>['tables', 'files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'browser_use-1',
    blockType: 'browser_use',
    label: 'Browser Use competitor pricing scraper',
    prompt:
        'Create a scheduled workflow that runs Browser Use weekly to navigate competitor pricing pages, captures the current plans and prices, diffs against last week, and posts changes to Slack.',
    iconId: 'brand/browser-use-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'browser_use-2',
    blockType: 'browser_use',
    label: 'Browser Use legacy ERP scraper',
    prompt:
        'Create a workflow that uses Browser Use to log into a legacy ERP without an API, exports daily reports, parses them into a table, and posts a summary to Slack so old systems still feed modern ops.',
    iconId: 'brand/browser-use-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'browser_use-3',
    blockType: 'browser_use',
    label: 'Browser Use + Stagehand cross-tool QA',
    prompt:
        'Create a workflow that uses Browser Use and Stagehand together to run scripted browser flows against staging, captures screenshots, and writes a regression report.',
    iconId: 'brand/browser-use-icon',
    modules: <String>['files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'browser_use-4',
    blockType: 'browser_use',
    label: 'Browser Use + Stagehand expense-portal grabber',
    prompt:
        'Build a workflow that uses Browser Use and Stagehand to automate expense-portal data pulls from suppliers, captures the structured data, and writes to a finance table.',
    iconId: 'brand/browser-use-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'browser_use-5',
    blockType: 'browser_use',
    label: 'Browser Use invoice-portal collector',
    prompt:
        'Create a workflow that uses Browser Use to log into vendor invoice portals weekly, downloads outstanding invoices, and writes the metadata to a finance table.',
    iconId: 'brand/browser-use-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'browser_use-6',
    blockType: 'browser_use',
    label: 'Browser Use review-site monitor',
    prompt:
        'Build a workflow that uses Browser Use to scrape G2 and Capterra review pages for brand mentions, classifies sentiment, and writes notable reviews to a tracking table.',
    iconId: 'brand/browser-use-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'buffer-0',
    blockType: 'buffer',
    label: 'Buffer blog-to-social queue',
    prompt:
        'Build a workflow that takes a blog post URL and summary, writes a short social caption for it, and adds a Buffer post to the queue for each connected channel returned by Get Channels.',
    iconId: 'brand/buffer-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'buffer-1',
    blockType: 'buffer',
    label: 'Buffer weekly content calendar',
    prompt:
        'Create a workflow that reads next week\'s content calendar from a table and creates a custom-scheduled Buffer post for each row with its channel, caption, and publish time, then writes the new post IDs back to the table.',
    iconId: 'brand/buffer-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'buffer-2',
    blockType: 'buffer',
    label: 'Buffer post from generated art',
    prompt:
        'Build a workflow that generates an on-brand image with an AI image model, writes a matching caption, and creates a Buffer post with the image attached, scheduled for tomorrow morning.',
    iconId: 'brand/buffer-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'buffer-3',
    blockType: 'buffer',
    label: 'Buffer failed-post alert to Slack',
    prompt:
        'Create a scheduled workflow that lists Buffer posts with status error, and for each failed post sends a Slack alert with the channel, the post text, and the publishing error message so the team can fix and reschedule it.',
    iconId: 'brand/buffer-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'buffer-4',
    blockType: 'buffer',
    label: 'Buffer daily queue health check',
    prompt:
        'Build a scheduled daily workflow that gets all Buffer channels, flags any with a paused queue or disconnected account, counts scheduled posts per channel for the next 3 days, and emails a digest highlighting channels with an empty queue.',
    iconId: 'brand/buffer-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'buffer-5',
    blockType: 'buffer',
    label: 'Buffer ideas from Slack',
    prompt:
        'Create a workflow triggered by a Slack message in the content-ideas channel that cleans up the message text and saves it as a Buffer idea with a short title so the marketing team can draft it later.',
    iconId: 'brand/buffer-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'buffer-6',
    blockType: 'buffer',
    label: 'Buffer launch announcement',
    prompt:
        'Build a workflow that takes launch notes, writes a tailored announcement per social network, and shares a Buffer post immediately on every connected channel, then reports the external links of the published posts.',
    iconId: 'brand/buffer-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'buffer-7',
    blockType: 'buffer',
    label: 'Buffer evergreen recycler',
    prompt:
        'Create a scheduled weekly workflow that lists Buffer posts sent more than 90 days ago, picks the top evergreen ones, refreshes their captions, and re-adds them to the queue as new posts.',
    iconId: 'brand/buffer-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'calcom-0',
    blockType: 'calcom',
    label: 'Cal.com booking prep brief',
    prompt:
        'Build a workflow that runs 30 minutes before a Cal.com booking, researches the attendee with Apollo, and emails the host a structured prep brief.',
    iconId: 'brand/cal-com-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'calcom',
  ),
  SuggestionTemplate(
    id: 'calcom-1',
    blockType: 'calcom',
    label: 'Cal.com post-meeting recap',
    prompt:
        'Create a workflow that runs after a Cal.com meeting ends, summarizes the meeting notes, and updates the linked Salesforce or HubSpot opportunity.',
    iconId: 'brand/cal-com-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'calcom',
  ),
  SuggestionTemplate(
    id: 'calcom-2',
    blockType: 'calcom',
    label: 'Cal.com no-show recovery',
    prompt:
        'Build a workflow that detects Cal.com no-shows, sends a polite reschedule email with a one-tap link, and updates the deal record with the no-show event.',
    iconId: 'brand/cal-com-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'calcom',
  ),
  SuggestionTemplate(
    id: 'calcom-3',
    blockType: 'calcom',
    label: 'Cal.com + Loops nurture',
    prompt:
        'Create a workflow that on a Cal.com booking enrolls the attendee into a Loops nurture campaign tailored to the meeting topic.',
    iconId: 'brand/cal-com-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'calcom',
  ),
  SuggestionTemplate(
    id: 'calcom-4',
    blockType: 'calcom',
    label: 'Cal.com round-robin balancer',
    prompt:
        'Build a workflow that watches Cal.com round-robin assignments, ensures equitable distribution across the team weekly, and adjusts the weights based on capacity.',
    iconId: 'brand/cal-com-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'calcom',
  ),
  SuggestionTemplate(
    id: 'calcom-5',
    blockType: 'calcom',
    label: 'Cal.com webhook to CRM',
    prompt:
        'Create a workflow triggered by a Cal.com booking webhook that creates or updates the contact in HubSpot, sets the lifecycle stage, and assigns the right owner.',
    iconId: 'brand/cal-com-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'calcom',
  ),
  SuggestionTemplate(
    id: 'calcom-6',
    blockType: 'calcom',
    label: 'Cal.com reschedule chaser',
    prompt:
        'Build a scheduled workflow that finds Cal.com bookings that have been rescheduled more than twice, posts a Slack alert to the host, and proposes a fixed time.',
    iconId: 'brand/cal-com-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'calcom',
  ),
  SuggestionTemplate(
    id: 'calendly-0',
    blockType: 'calendly',
    label: 'Calendly booking follow-up',
    prompt:
        'Build a workflow that monitors new Calendly bookings, researches each attendee and their company, prepares a pre-meeting brief with relevant context, and sends a personalized confirmation email with an agenda and any prep materials.',
    iconId: 'brand/calendly-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'calendly-1',
    blockType: 'calendly',
    label: 'Calendly meeting-prep brief',
    prompt:
        'Build a workflow that runs 30 minutes before a Calendly booking, researches the attendee and company with Apollo, and emails the host a structured prep brief.',
    iconId: 'brand/calendly-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'calendly-2',
    blockType: 'calendly',
    label: 'Calendly post-meeting recap',
    prompt:
        'Create a workflow that runs after a Calendly meeting ends, pulls the meeting notes from the calendar, writes a CRM-ready summary, and updates the linked Salesforce opportunity.',
    iconId: 'brand/calendly-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'calendly-3',
    blockType: 'calendly',
    label: 'Calendly no-show recovery',
    prompt:
        'Build a workflow that detects Calendly no-shows, sends a polite reschedule email with a one-tap link, and updates the deal record with the no-show event.',
    iconId: 'brand/calendly-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'calendly-4',
    blockType: 'calendly',
    label: 'Calendly + Loops nurture',
    prompt:
        'Create a workflow that on a Calendly booking enrolls the attendee into a Loops nurture campaign tailored to the meeting topic, ensuring follow-up emails reach them before the meeting.',
    iconId: 'brand/calendly-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'calendly-5',
    blockType: 'calendly',
    label: 'Calendly no-show tracker',
    prompt:
        'Build a scheduled workflow that lists yesterday\'s Calendly scheduled events, checks invitee status to find no-shows, logs them to a table for follow-up, and posts a recap of attended versus missed meetings to Slack.',
    iconId: 'brand/calendly-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'calendly-6',
    blockType: 'calendly',
    label: 'Calendly booking prep brief',
    prompt:
        'Create a workflow that on a new Calendly booking fetches the scheduled event and invitee details, researches the attendee and their company, and emails the meeting owner a one-page prep brief before the call.',
    iconId: 'brand/calendly-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cbinsights-0',
    blockType: 'cbinsights',
    label: 'CB Insights account enrichment',
    prompt:
        'Create a workflow that watches my accounts table for new company names, resolves each to a CB Insights organization ID with the free lookup, pulls firmographics and the Mosaic Score, and writes headcount, sector, funding stage, and score back to the row.',
    iconId: 'brand/cb-insights-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cbinsights-1',
    blockType: 'cbinsights',
    label: 'CB Insights ICP company list',
    prompt:
        'Build a workflow that searches CB Insights firmographics for companies matching my ideal customer profile — market, headcount band, funding raised, and headquarters country — pages through every result, and writes the list to a table for the SDR team.',
    iconId: 'emcn/building',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cbinsights-2',
    blockType: 'cbinsights',
    label: 'CB Insights exit probability watchlist',
    prompt:
        'Create a scheduled workflow that reads the outlook for every company on my watchlist, flags any whose two-year IPO or M&A exit probability moved meaningfully against its peer mean, and posts the changes to Slack.',
    iconId: 'emcn/sprout',
    modules: <String>['tables', 'scheduled', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cbinsights-3',
    blockType: 'cbinsights',
    label: 'CB Insights funding window alerts',
    prompt:
        'Build a workflow that checks the estimated funding window for each company in my pipeline every week and emails me the ones entering their window in the next 60 days, with the cohort rate and their last round.',
    iconId: 'brand/cb-insights-icon',
    modules: <String>['tables', 'scheduled', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cbinsights-4',
    blockType: 'cbinsights',
    label: 'CB Insights scouting report brief',
    prompt:
        'Create an agent that takes a company name, resolves it in CB Insights, generates a Scouting Report, and turns the business model, market position, strengths, and opportunities into a one-page brief I can take into a meeting.',
    iconId: 'emcn/sparkles',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cbinsights-5',
    blockType: 'cbinsights',
    label: 'CB Insights leadership tracker',
    prompt:
        'Build a workflow that pulls management and board data for my target accounts, extracts each executive with their title, education, and prior roles, and writes the buying committee to a table so reps know who to engage.',
    iconId: 'emcn/users',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cbinsights-6',
    blockType: 'cbinsights',
    label: 'CB Insights competitor strategy map',
    prompt:
        'Create a workflow that takes a competitor, pulls its CB Insights strategy map, and summarizes which categories it is investing in, partnering across, and acquiring into — then posts the summary to my strategy channel.',
    iconId: 'emcn/search',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cbinsights-7',
    blockType: 'cbinsights',
    label: 'CB Insights portfolio exit digest',
    prompt:
        'Build a scheduled workflow that reads portfolio exits for the investors I track, summarizes each exit with the company, round, and amount, and emails a weekly digest to the investment team.',
    iconId: 'brand/cb-insights-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cbinsights-8',
    blockType: 'cbinsights',
    label: 'CB Insights market research agent',
    prompt:
        'Create an agent that answers private-market questions by asking ChatCBI, then verifies the claims against firmographics and funding data before returning an answer with its sources.',
    iconId: 'emcn/list-checks',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cbinsights-9',
    blockType: 'cbinsights',
    label: 'CB Insights revenue growth screen',
    prompt:
        'Build a workflow that pulls revenue by year for my target list, computes year-over-year growth, ranks the companies by it, and writes the ranked screen to a table with the sources behind each figure.',
    iconId: 'emcn/sprout',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'checkr-0',
    blockType: 'checkr',
    label: 'Background check on offer',
    prompt:
        'Build a workflow that runs when a candidate reaches the offer stage in Greenhouse, creates the candidate in Checkr with their email, sends a Checkr invitation for the role’s package, and posts the invitation link and status to the hiring channel in Slack.',
    iconId: 'brand/checkr-icon',
    modules: <String>['agent', 'workflows'],
    featured: true,
  ),
  SuggestionTemplate(
    id: 'checkr-1',
    blockType: 'checkr',
    label: 'Checkr report completed alert',
    prompt:
        'Create a workflow triggered by a completed Checkr report that reads the report, summarizes the result and any screenings that need review, and notifies the recruiter in Slack with a clear or consider recommendation.',
    iconId: 'brand/checkr-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'checkr-2',
    blockType: 'checkr',
    label: 'Consider report review queue',
    prompt:
        'Build a workflow that runs when a Checkr report completes with a consider result, pulls the report’s assessments and the records from each criminal screening, drafts an individualized assessment summary for the adjudicator, and logs the case to a review table.',
    iconId: 'brand/checkr-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'checkr-3',
    blockType: 'checkr',
    label: 'Expired invitation follow-up',
    prompt:
        'Create a workflow triggered when a Checkr invitation expires that looks up the candidate, sends a friendly reminder email explaining the next steps, creates a fresh invitation for the same package, and records the follow-up in a tracking table.',
    iconId: 'brand/checkr-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'checkr-4',
    blockType: 'checkr',
    label: 'Background check status digest',
    prompt:
        'Build a scheduled daily workflow that lists pending Checkr invitations, reads each invited candidate’s reports and their estimated completion dates, and sends the hiring team a digest of who is waiting, what is delayed, and which candidates need to act.',
    iconId: 'brand/checkr-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'checkr-5',
    blockType: 'checkr',
    label: 'Clear report to onboarding',
    prompt:
        'Create a workflow that runs when a Checkr report completes with a clear result, engages the report, tags it as onboarded, and creates the new hire’s onboarding tasks in your project tracker with their start date.',
    iconId: 'brand/checkr-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'checkr-6',
    blockType: 'checkr',
    label: 'Annual driver rescreening',
    prompt:
        'Build a workflow that reads a table of active drivers, creates a yearly Checkr subscription for each driver who does not have one, enrolls them in continuous MVR monitoring, and writes the subscription and continuous check IDs back to the table.',
    iconId: 'brand/checkr-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'circleback-0',
    blockType: 'circleback',
    label: 'Circleback recap to Slack',
    prompt:
        'Build a workflow that triggers when a meeting is processed in Circleback, takes the notes and action items from the payload, and posts a clean recap to the relevant Slack channel.',
    iconId: 'brand/circleback-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'circleback-1',
    blockType: 'circleback',
    label: 'Circleback action-item tracker',
    prompt:
        'Create a workflow that triggers when a Circleback meeting is processed, reads the action items from the payload, and writes each one to a tasks table with the owner and due date.',
    iconId: 'emcn/clipboard-list',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'circleback-2',
    blockType: 'circleback',
    label: 'Circleback notes to Notion',
    prompt:
        'Build a workflow that triggers when a meeting is processed in Circleback, pulls the notes, attendees, and transcript from the payload, and writes a structured meeting note to Notion with next steps.',
    iconId: 'emcn/table',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'circleback-3',
    blockType: 'circleback',
    label: 'Circleback meeting prep brief',
    prompt:
        'Build a scheduled workflow that lists upcoming calendar events from Circleback each morning, pulls past meetings and notes for the same attendees, and posts a prep brief for each external meeting to Slack.',
    iconId: 'brand/circleback-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'circleback-4',
    blockType: 'circleback',
    label: 'Circleback action-item chaser',
    prompt:
        'Create a scheduled workflow that lists pending Circleback action items across the workspace each week, groups them by assignee, and sends each owner a summary of what is still open.',
    iconId: 'brand/circleback-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'circleback-5',
    blockType: 'circleback',
    label: 'Circleback CRM updater',
    prompt:
        'Build a workflow that runs after a Circleback sales meeting, gets the full meeting with notes and insights, summarizes it into a deal-ready update, and writes it to the matching HubSpot or Salesforce record using the attendee company domain.',
    iconId: 'brand/circleback-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'circleback-6',
    blockType: 'circleback',
    label: 'Circleback customer-voice miner',
    prompt:
        'Create a workflow that searches Circleback meetings for a product or feature keyword, reads the matching transcripts, extracts notable customer quotes and pain points, and writes them to a tables-based research log.',
    iconId: 'brand/circleback-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'circleback-7',
    blockType: 'circleback',
    label: 'Circleback weekly meeting digest',
    prompt:
        'Build a scheduled weekly workflow that lists the past week of Circleback meetings, aggregates decisions, action items, and recurring themes, and posts a digest to the team Slack channel.',
    iconId: 'brand/circleback-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'circleback-8',
    blockType: 'circleback',
    label: 'Circleback tag janitor',
    prompt:
        'Create a workflow that lists Circleback meetings without tags, classifies each meeting from its name and attendees, and applies the right existing tag so meetings stay organized.',
    iconId: 'brand/circleback-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'clay-0',
    blockType: 'clay',
    label: 'Clay lead-list builder',
    prompt:
        'Build a workflow that reads a list of target prospects from a Sim table and pushes each one to a Clay table via the populate webhook, so Clay enriches them with role and intent signals through its own waterfall.',
    iconId: 'brand/clay-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'clay-1',
    blockType: 'clay',
    label: 'Clay CRM enricher',
    prompt:
        'Create a scheduled workflow that reads new HubSpot contacts and pushes each one to a Clay table via the populate webhook, so Clay runs its enrichment waterfall on role, seniority, and tech-stack signals.',
    iconId: 'brand/clay-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'clay-2',
    blockType: 'clay',
    label: 'Clay account pusher',
    prompt:
        'Build a scheduled workflow that reads target accounts from a Sim table and pushes each one to a Clay table via the populate webhook, so Clay enriches them with hiring, funding, and tech-change signals through its waterfall.',
    iconId: 'brand/clay-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'clay-3',
    blockType: 'clay',
    label: 'Clay outbound personalizer',
    prompt:
        'Create a workflow that reads a prospect record from a Sim table — including the role and company signals already gathered — drafts a personalized first-touch email, queues it for review, and pushes the prospect to a Clay table via the populate webhook for further enrichment.',
    iconId: 'brand/clay-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'clay-4',
    blockType: 'clay',
    label: 'Clay TAM seeder',
    prompt:
        'Build a workflow that reads a seed account list from Salesforce and pushes each account to a Clay table via the populate webhook, so Clay runs its lookalike and enrichment waterfall to expand the TAM.',
    iconId: 'brand/clay-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'clay-5',
    blockType: 'clay',
    label: 'Clay inbound lead router',
    prompt:
        'Create a workflow that scores each inbound HubSpot lead against the ICP using the fields already on the contact, routes high-fit leads to sales while parking the rest for nurture, and pushes every lead to a Clay table via the populate webhook for enrichment.',
    iconId: 'brand/clay-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'clay-6',
    blockType: 'clay',
    label: 'Clay enrichment pusher',
    prompt:
        'Build a scheduled workflow that reads new rows from a leads table and pushes each record to a Clay table via the populate webhook, so Clay runs its enrichment waterfall and the data flows back into my outbound stack automatically.',
    iconId: 'brand/clay-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'clerk-0',
    blockType: 'clerk',
    label: 'Clerk new-signup pipeline',
    prompt:
        'Build a scheduled workflow that lists recent Clerk users, creates each new signup in HubSpot with the right lifecycle stage, and enrolls them in a Loops onboarding sequence.',
    iconId: 'brand/clerk-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'clerk-1',
    blockType: 'clerk',
    label: 'Clerk MFA enrollment chaser',
    prompt:
        'Create a scheduled workflow that finds Clerk users without MFA enrolled in 30 days, sends in-app prompts via Loops, and writes enrollment progress to a security dashboard.',
    iconId: 'brand/clerk-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'clerk-2',
    blockType: 'clerk',
    label: 'Clerk session anomaly watcher',
    prompt:
        'Build a scheduled workflow that lists recent Clerk sessions, flags unusual patterns — impossible travel, repeated login failures — and pings the security Slack channel on real threats.',
    iconId: 'brand/clerk-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'clerk-3',
    blockType: 'clerk',
    label: 'Clerk org-management automator',
    prompt:
        'Create a workflow that on a new enterprise plan via Stripe creates a Clerk organization, invites the admin by email, and writes the Clerk org ID back to the Stripe customer.',
    iconId: 'brand/clerk-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'clerk-4',
    blockType: 'clerk',
    label: 'Clerk inactive-user cleaner',
    prompt:
        'Build a scheduled workflow that finds Clerk users with no sign-ins in 180 days, sends a re-engagement email, and bans accounts that stay inactive after a grace period.',
    iconId: 'brand/clerk-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'clerk-5',
    blockType: 'clerk',
    label: 'Clerk access-review automator',
    prompt:
        'Create a scheduled quarterly workflow that lists Clerk organizations and their memberships, requires owner re-attestation, and writes the review trail to a compliance table.',
    iconId: 'brand/clerk-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'clerk-6',
    blockType: 'clerk',
    label: 'Clerk user roster archiver',
    prompt:
        'Build a scheduled workflow that exports the full Clerk user and organization roster to S3 on a retention schedule, and writes the snapshot manifest to a compliance table.',
    iconId: 'brand/clerk-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'clickhouse-0',
    blockType: 'clickhouse',
    label: 'Natural-language ClickHouse query',
    prompt:
        'Build a workflow where I ask a question in plain English, an agent writes the matching ClickHouse SQL against my events table, runs the query, and returns the results formatted as a readable answer.',
    iconId: 'brand/click-house-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'clickhouse-1',
    blockType: 'clickhouse',
    label: 'Daily ClickHouse metrics digest',
    prompt:
        'Create a scheduled workflow that runs a set of ClickHouse aggregation queries each morning, summarizes the key trends and anomalies with an agent, and posts the digest to Slack.',
    iconId: 'emcn/file',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'clickhouse-2',
    blockType: 'clickhouse',
    label: 'Event ingestion to ClickHouse',
    prompt:
        'Build a workflow that takes incoming event payloads, maps them to the right columns with an agent, and bulk-inserts the rows into a ClickHouse table for analytics.',
    iconId: 'emcn/clipboard-list',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'clickhouse-3',
    blockType: 'clickhouse',
    label: 'Document a ClickHouse schema',
    prompt:
        'Build a workflow that introspects my ClickHouse database schema, then has an agent write clear documentation describing each table, its columns, types, and engine.',
    iconId: 'emcn/search',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'clickhouse-4',
    blockType: 'clickhouse',
    label: 'Scheduled ClickHouse maintenance',
    prompt:
        'Create a scheduled workflow that runs OPTIMIZE TABLE on my high-write ClickHouse tables each night to merge parts, then reports the resulting part counts and storage size.',
    iconId: 'emcn/wrench',
    modules: <String>['scheduled', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'clickhouse-5',
    blockType: 'clickhouse',
    label: 'ClickHouse partition cleanup',
    prompt:
        'Build a scheduled workflow that enforces a retention policy on my ClickHouse events table: take an explicit cutoff date as input, list the table partitions, select only the partitions on that exact table whose range ends strictly before the cutoff, and drop just those. Never infer the cutoff and never drop a partition that is not clearly past it.',
    iconId: 'emcn/trash',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'clickhouse-6',
    blockType: 'clickhouse',
    label: 'Alert on slow ClickHouse queries',
    prompt:
        'Create a scheduled workflow that lists ClickHouse running queries and posts a Slack alert for any whose elapsed time exceeds an explicit threshold I set, including the query_id, user, and elapsed time so a human can investigate and decide whether to intervene.',
    iconId: 'emcn/bell',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'clickhouse-7',
    blockType: 'clickhouse',
    label: 'Provision a ClickHouse table from a spec',
    prompt:
        'Build a workflow where I describe the table I need in plain English, an agent designs the columns, engine, and ORDER BY key, and the workflow creates the ClickHouse table.',
    iconId: 'emcn/database',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'clickhouse-8',
    blockType: 'clickhouse',
    label: 'ClickHouse storage growth report',
    prompt:
        'Create a scheduled workflow that collects ClickHouse table stats (rows and size on disk) each week, has an agent summarize the largest tables and fastest growth, and posts the report to Slack.',
    iconId: 'emcn/server',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'clickup-0',
    blockType: 'clickup',
    label: 'ClickUp task intake',
    prompt:
        'Build a workflow that turns incoming Slack requests into ClickUp tasks in the right list with a clear name, description, priority, and due date, then replies in the thread with the task link.',
    iconId: 'brand/click-up-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'clickup',
  ),
  SuggestionTemplate(
    id: 'clickup-1',
    blockType: 'clickup',
    label: 'ClickUp standup digest',
    prompt:
        'Create a scheduled weekday workflow that pulls open ClickUp tasks for each list, groups them by assignee and status, and posts a morning standup summary to the team Slack channel.',
    iconId: 'brand/click-up-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'clickup',
  ),
  SuggestionTemplate(
    id: 'clickup-2',
    blockType: 'clickup',
    label: 'ClickUp overdue-task nudger',
    prompt:
        'Build a scheduled workflow that searches ClickUp for tasks past their due date, adds a comment asking for a status update, and emails each assignee a digest of their overdue work.',
    iconId: 'brand/click-up-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'clickup',
  ),
  SuggestionTemplate(
    id: 'clickup-3',
    blockType: 'clickup',
    label: 'ClickUp bug triager',
    prompt:
        'Create a workflow that reads newly reported bugs from a ClickUp list, classifies each by severity and component with an agent, sets the priority and tags accordingly, and opens a matching GitHub issue for engineering.',
    iconId: 'brand/click-up-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'clickup',
  ),
  SuggestionTemplate(
    id: 'clickup-4',
    blockType: 'clickup',
    label: 'ClickUp sprint retro writer',
    prompt:
        'Build a workflow that pulls the ClickUp tasks completed during a sprint, summarizes wins, blockers, and recurring themes with an agent, and shares a retro document with the team in Slack.',
    iconId: 'brand/click-up-icon',
    modules: <String>['agent', 'files', 'workflows'],
    providerId: 'clickup',
  ),
  SuggestionTemplate(
    id: 'clickup-5',
    blockType: 'clickup',
    label: 'ClickUp customer onboarding launcher',
    prompt:
        'Create a workflow that on a closed-won Salesforce opportunity creates a ClickUp onboarding task with the right assignees and due date, attaches the signed order form, and writes the task link back to the opportunity.',
    iconId: 'brand/click-up-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'clickup',
  ),
  SuggestionTemplate(
    id: 'clickup-6',
    blockType: 'clickup',
    label: 'ClickUp meeting action items',
    prompt:
        'Build a workflow that takes meeting notes, extracts action items with an agent, creates a ClickUp task for each with the right assignee and due date, and replies with a checklist of created tasks.',
    iconId: 'brand/click-up-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'clickup',
  ),
  SuggestionTemplate(
    id: 'cloudflare-0',
    blockType: 'cloudflare',
    label: 'Cloudflare DNS change tracker',
    prompt:
        'Create a scheduled workflow that pulls every Cloudflare DNS record for my zones each hour, diffs the snapshot against the previous run, logs added, removed, and modified records to a table, and posts a Slack alert when sensitive records like MX or NS change.',
    iconId: 'brand/cloudflare-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudflare-1',
    blockType: 'cloudflare',
    label: 'Cloudflare cache purge on deploy',
    prompt:
        'Build a workflow that fires when a Vercel deployment succeeds on production, purges the Cloudflare cache for the affected hostnames, verifies the new content is being served, and posts a confirmation message to Slack with the purged paths.',
    iconId: 'brand/cloudflare-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudflare-2',
    blockType: 'cloudflare',
    label: 'Cloudflare SSL and zone check',
    prompt:
        'Create a scheduled weekly workflow that inspects every Cloudflare zone for SSL certificate status, security level, and zone settings drift, logs findings to a table, and opens Linear tickets for any zones that need attention.',
    iconId: 'brand/cloudflare-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudflare-3',
    blockType: 'cloudflare',
    label: 'Cloudflare DNS analytics digest',
    prompt:
        'Build a scheduled workflow that pulls Cloudflare DNS analytics for the top zones every Monday, identifies query spikes, anomalies, and surges in particular record types, and emails a written analysis to the platform team with traffic graphs and recommendations.',
    iconId: 'brand/cloudflare-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudflare-4',
    blockType: 'cloudflare',
    label: 'Cloudflare zone provisioning',
    prompt:
        'Create a workflow that accepts a domain name from a form, creates a new Cloudflare zone, sets opinionated default DNS records and zone settings, generates the nameserver instructions, and posts the setup summary to Slack so the team can finalize delegation.',
    iconId: 'brand/cloudflare-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudflare-5',
    blockType: 'cloudflare',
    label: 'Cloudflare DNS bulk importer',
    prompt:
        'Build a workflow that reads a table of DNS records — name, type, content, TTL — validates each row, creates or updates the matching record in Cloudflare, and writes results back to the table so DNS changes are versioned and reviewable.',
    iconId: 'brand/cloudflare-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudflare-6',
    blockType: 'cloudflare',
    label: 'Cloudflare zone policy enforcer',
    prompt:
        'Create a scheduled workflow that reads a baseline of required Cloudflare zone settings from a knowledge base, compares it against every zone weekly, automatically reverts unauthorized changes, and emails a compliance report to security leadership.',
    iconId: 'brand/cloudflare-icon',
    modules: <String>['knowledge-base', 'scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudflare-7',
    blockType: 'cloudflare',
    label: 'Cloudflare WAF and rate limit rollout',
    prompt:
        'Build a workflow that reads a table of WAF rules — expression, action, and rate limit — validates each row against the zone it targets, deploys it into the matching Cloudflare ruleset phase, and posts a Slack summary of every rule created, changed, or skipped.',
    iconId: 'brand/cloudflare-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudflare-8',
    blockType: 'cloudflare',
    label: 'Cloudflare Zero Trust access review',
    prompt:
        'Create a scheduled monthly workflow that lists every Cloudflare Access application and its policies, flags applications with no policy, overly broad email-domain rules, or bypass decisions, logs the findings to a table, and emails an access review to security leadership.',
    iconId: 'brand/cloudflare-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudformation-0',
    blockType: 'cloudformation',
    label: 'CloudFormation drift detector',
    prompt:
        'Create a scheduled daily workflow that runs drift detection on every CloudFormation stack in my AWS account, waits for detection to complete, summarizes drifted resources, logs them to a table, and posts a Slack alert when any production stack drifts.',
    iconId: 'brand/cloud-formation-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudformation-1',
    blockType: 'cloudformation',
    label: 'CloudFormation stack inventory',
    prompt:
        'Build a scheduled weekly workflow that describes every CloudFormation stack, lists its resources, and writes a unified inventory of stacks, status, region, and resource counts into a tracking table so the platform team has a single source of truth.',
    iconId: 'brand/cloud-formation-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudformation-2',
    blockType: 'cloudformation',
    label: 'CloudFormation template validator',
    prompt:
        'Create a workflow triggered when a CloudFormation template is changed in a GitHub pull request. Pull the template, validate it via the CloudFormation API, summarize any syntax or structural errors, and post the validation result as a PR comment to block merges on broken templates.',
    iconId: 'brand/cloud-formation-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudformation-3',
    blockType: 'cloudformation',
    label: 'CloudFormation failure investigator',
    prompt:
        'Build a scheduled workflow that polls CloudFormation stack events every few minutes, detects rollbacks and create-failed events, pulls the failure reason and recent events from the stack, summarizes the root cause, opens a Linear ticket with the diagnosis, and posts to the on-call Slack channel.',
    iconId: 'brand/cloud-formation-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudformation-4',
    blockType: 'cloudformation',
    label: 'CloudFormation template archive',
    prompt:
        'Create a scheduled workflow that retrieves the deployed template for every CloudFormation stack, stores each template as a versioned file in your files store, and updates a knowledge base so engineers can search infrastructure definitions in natural language.',
    iconId: 'brand/cloud-formation-icon',
    modules: <String>[
      'scheduled',
      'files',
      'knowledge-base',
      'agent',
      'workflows',
    ],
  ),
  SuggestionTemplate(
    id: 'cloudformation-5',
    blockType: 'cloudformation',
    label: 'CloudFormation change report',
    prompt:
        'Build a scheduled weekly workflow that pulls CloudFormation stack events, summarizes resource creates, updates, and deletes across the account, classifies risky changes, and writes a written change report file for platform leadership review.',
    iconId: 'brand/cloud-formation-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudformation-6',
    blockType: 'cloudformation',
    label: 'CloudFormation pre-deploy drift gate',
    prompt:
        'Create a workflow that runs before a deploy, initiates drift detection on the target CloudFormation stack, polls until drift detection completes, and either approves the deploy or blocks it with a Slack alert explaining the drifted resources.',
    iconId: 'brand/cloud-formation-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudformation-7',
    blockType: 'cloudformation',
    label: 'CloudFormation change set approval',
    prompt:
        'Build a workflow that creates a CloudFormation change set for a stack update, describes the proposed resource changes, posts a summary to Slack for approval, and executes the change set only after an approver replies, otherwise deletes the change set.',
    iconId: 'brand/cloud-formation-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudformation-8',
    blockType: 'cloudformation',
    label: 'CloudFormation environment provisioner',
    prompt:
        'Create a workflow that takes an environment name and template parameters as input, creates a new CloudFormation stack for that environment, polls stack events until it reaches CREATE_COMPLETE or fails, and posts the stack outputs to Slack.',
    iconId: 'brand/cloud-formation-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudtrail-0',
    blockType: 'cloudtrail',
    label: 'CloudTrail root login alerter',
    prompt:
        'Create a scheduled workflow that looks up AWS CloudTrail ConsoleLogin events every 15 minutes, flags any sign-in by the root user or a login without MFA, and posts the actor, source IP, and time to a Slack security channel.',
    iconId: 'brand/cloud-trail-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudtrail-1',
    blockType: 'cloudtrail',
    label: 'CloudTrail IAM change review',
    prompt:
        'Build a daily workflow that looks up AWS CloudTrail events from iam.amazonaws.com, summarizes every policy attach, role creation, and access key change with the principal who made it, and writes the review to a compliance table.',
    iconId: 'brand/cloud-trail-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudtrail-2',
    blockType: 'cloudtrail',
    label: 'CloudTrail trail health monitor',
    prompt:
        'Create a scheduled workflow that lists every AWS CloudTrail trail, checks each trail status for logging stopped or recent delivery errors, and opens a PagerDuty incident when a trail stops recording.',
    iconId: 'brand/cloud-trail-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudtrail-3',
    blockType: 'cloudtrail',
    label: 'CloudTrail access key forensics',
    prompt:
        'Build a workflow that takes an AWS access key ID, looks up every CloudTrail event made with it in the last 90 days, groups the calls by service and source IP, and returns a timeline of what that credential did.',
    iconId: 'brand/cloud-trail-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudtrail-4',
    blockType: 'cloudtrail',
    label: 'CloudTrail Lake audit agent',
    prompt:
        'Build a Slack agent that turns natural-language audit questions into CloudTrail Lake SQL, starts the query, polls until it finishes, and returns the result rows with the SQL it ran for review.',
    iconId: 'brand/cloud-trail-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudtrail-5',
    blockType: 'cloudtrail',
    label: 'CloudTrail data-event coverage audit',
    prompt:
        'Create a weekly workflow that reads the event selectors of every AWS CloudTrail trail, reports which trails are missing management event logging or S3 data events, and writes the gaps to a compliance table.',
    iconId: 'brand/cloud-trail-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudtrail-6',
    blockType: 'cloudtrail',
    label: 'CloudTrail offboarding evidence pack',
    prompt:
        'Build a workflow that, given a departing employee username, looks up all their AWS CloudTrail activity from the last 90 days, summarizes the resources they touched, and emails an evidence pack to the security team.',
    iconId: 'brand/cloud-trail-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudtrail-7',
    blockType: 'cloudtrail',
    label: 'CloudTrail Insights anomaly digest',
    prompt:
        'Create a daily workflow that looks up AWS CloudTrail Insights events, correlates each API call-rate or error-rate anomaly with the principals active at that time, and posts a digest to Slack.',
    iconId: 'brand/cloud-trail-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudwatch-0',
    blockType: 'cloudwatch',
    label: 'CloudWatch alarm digest',
    prompt:
        'Create a scheduled daily workflow that summarizes the past 24 hours of CloudWatch alarms by service and severity, identifies repeat offenders, and posts a digest to Slack.',
    iconId: 'brand/cloud-watch-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudwatch-1',
    blockType: 'cloudwatch',
    label: 'CloudWatch log triage',
    prompt:
        'Build a scheduled workflow that runs CloudWatch Logs Insights queries hourly for error patterns, clusters matches, writes top groups to a triage table, and pings the on-call engineer.',
    iconId: 'brand/cloud-watch-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudwatch-2',
    blockType: 'cloudwatch',
    label: 'CloudWatch cost-control alerts',
    prompt:
        'Create a scheduled workflow that pulls CloudWatch billing alarms daily, projects month-end spend by service, and posts an alert when projection exceeds budget thresholds.',
    iconId: 'brand/cloud-watch-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudwatch-3',
    blockType: 'cloudwatch',
    label: 'CloudWatch incident scribe',
    prompt:
        'Build a scheduled workflow that polls CloudWatch alarms every few minutes for any in ALARM state, captures the surrounding metrics and recent log excerpts, and writes a timeline file for the incident review.',
    iconId: 'brand/cloud-watch-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudwatch-4',
    blockType: 'cloudwatch',
    label: 'CloudWatch SLO burn-rate watcher',
    prompt:
        'Create a workflow that monitors CloudWatch SLO burn rate every five minutes, classifies severity, and pages the on-call team via PagerDuty when burn exceeds fast-burn thresholds.',
    iconId: 'brand/cloud-watch-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudwatch-5',
    blockType: 'cloudwatch',
    label: 'CloudWatch metric archiver',
    prompt:
        'Build a scheduled workflow that exports CloudWatch metric snapshots into S3 long-term storage, preserving granularity for compliance, and writing a manifest table.',
    iconId: 'brand/cloud-watch-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cloudwatch-6',
    blockType: 'cloudwatch',
    label: 'CloudWatch log error triager',
    prompt:
        'Create a workflow that runs a CloudWatch Logs Insights query against application log groups every few minutes, groups recurring error signatures with an agent, opens a Linear issue for any new error pattern, and posts a Slack alert.',
    iconId: 'brand/cloud-watch-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'coda-0',
    blockType: 'coda',
    label: 'Coda meeting notes publisher',
    prompt:
        'Build a workflow that takes a meeting transcript, has an agent write a summary with decisions and action items, creates a Coda page for the meeting in the team doc, and inserts each action item as a row in the Coda tasks table with owner and due date.',
    iconId: 'brand/coda-icon',
    modules: <String>['agent', 'workflows'],
    featured: true,
  ),
  SuggestionTemplate(
    id: 'coda-1',
    blockType: 'coda',
    label: 'Coda OKR progress report',
    prompt:
        'Create a scheduled workflow that reads the OKR table in a Coda doc every Friday, computes progress per objective from the key result rows, and appends a weekly progress summary to the OKR review page in Markdown.',
    iconId: 'brand/coda-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'coda-2',
    blockType: 'coda',
    label: 'Coda CRM lead upsert',
    prompt:
        'Build a workflow that receives new leads from a form webhook, has an agent normalize company and contact fields, and upserts each lead into a Coda CRM table keyed on email so repeat submissions update the existing row.',
    iconId: 'brand/coda-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'coda-3',
    blockType: 'coda',
    label: 'Coda bug tracker triage',
    prompt:
        'Create a workflow that lists new rows in a Coda bug tracker table, has an agent classify severity and suggest an owner for each bug, updates the rows with the triage fields, and posts the high-severity bugs to Slack.',
    iconId: 'brand/coda-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'coda-4',
    blockType: 'coda',
    label: 'Coda wiki to knowledge base',
    prompt:
        'Build a scheduled workflow that lists the pages of a Coda team wiki doc, reads each page as text, and syncs the content into a Sim knowledge base so agents can answer questions from the wiki.',
    iconId: 'brand/coda-icon',
    modules: <String>['scheduled', 'knowledge-base', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'coda-5',
    blockType: 'coda',
    label: 'Coda table to Sim table mirror',
    prompt:
        'Create a scheduled workflow that reads rows changed since the last run from a Coda table using its sync token and mirrors them into a Sim table for reporting and downstream agent runs.',
    iconId: 'brand/coda-icon',
    modules: <String>['scheduled', 'tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'coda-6',
    blockType: 'coda',
    label: 'Coda project status digest',
    prompt:
        'Build a scheduled workflow that reads the project tracker table in a Coda doc each morning, has an agent flag overdue and blocked projects, and emails a status digest to project leads with links to each row.',
    iconId: 'brand/coda-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'coda-7',
    blockType: 'coda',
    label: 'Coda doc access audit',
    prompt:
        'Create a scheduled workflow that lists the Coda docs in a workspace, reads the sharing permissions and sharing settings on each, and writes any docs shared with anyone or outside domains to an audit table for review.',
    iconId: 'brand/coda-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'coda-8',
    blockType: 'coda',
    label: 'Coda doc engagement report',
    prompt:
        'Build a scheduled workflow that pulls last week of Coda doc analytics, ranks docs by sessions and views, and posts the most and least used team docs to Slack so owners can archive stale docs.',
    iconId: 'brand/coda-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'codepipeline-0',
    blockType: 'codepipeline',
    label: 'CodePipeline deploy approver',
    prompt:
        'Build a workflow that checks a CodePipeline pipeline for pending manual approvals, posts the change summary and source revisions to Slack, and approves or rejects the deployment based on the team lead reply.',
    iconId: 'brand/code-pipeline-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'codepipeline-1',
    blockType: 'codepipeline',
    label: 'CodePipeline failure triage',
    prompt:
        'Create a scheduled workflow that polls CodePipeline executions every few minutes, and when one fails, pulls the pipeline state to find the failing stage and action error, opens a Linear issue, and alerts the on-call channel in Slack.',
    iconId: 'brand/code-pipeline-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'codepipeline-2',
    blockType: 'codepipeline',
    label: 'CodePipeline release train',
    prompt:
        'Build a scheduled workflow that starts the release CodePipeline pipeline every weekday at 9am with the release version as a pipeline variable, then posts the execution ID and a link to Slack.',
    iconId: 'brand/code-pipeline-icon',
    modules: <String>['scheduled', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'codepipeline-3',
    blockType: 'codepipeline',
    label: 'CodePipeline deploy digest',
    prompt:
        'Create a scheduled daily workflow that lists executions across the team CodePipeline pipelines, summarizes successes, failures, and rollbacks with their source revisions, and posts a digest to Slack.',
    iconId: 'brand/code-pipeline-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'codepipeline-4',
    blockType: 'codepipeline',
    label: 'CodePipeline flaky-stage retrier',
    prompt:
        'Build a scheduled workflow that finds failed CodePipeline executions, retries the failed stage once with failed-actions mode, and escalates to PagerDuty if the retry fails again.',
    iconId: 'brand/code-pipeline-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'codepipeline-5',
    blockType: 'codepipeline',
    label: 'CodePipeline rollback brake',
    prompt:
        'Create a workflow that watches CloudWatch alarms after a deployment, and when an error-rate alarm fires while a CodePipeline execution is in progress, stops the execution with a reason and notifies the release channel.',
    iconId: 'brand/code-pipeline-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'codepipeline-6',
    blockType: 'codepipeline',
    label: 'CodePipeline deployment audit log',
    prompt:
        'Build a scheduled workflow that records every CodePipeline execution — pipeline, status, trigger, source revisions, and timing — into a table for compliance and deployment-frequency reporting.',
    iconId: 'brand/code-pipeline-icon',
    modules: <String>['scheduled', 'tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'confluence-0',
    blockType: 'confluence',
    label: 'PagerDuty incident coordinator',
    prompt:
        'Create a knowledge base connected to my Confluence or Notion with runbooks and incident procedures. Then build a workflow triggered by PagerDuty incidents that searches the runbooks, gathers related Datadog alerts, identifies the on-call rotation, and posts a comprehensive incident brief to Slack.',
    iconId: 'brand/pager-duty-icon',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
    providerId: 'confluence',
  ),
  SuggestionTemplate(
    id: 'confluence-1',
    blockType: 'confluence',
    label: 'Confluence knowledge base sync',
    prompt:
        'Create a knowledge base connected to my Confluence workspace so all wiki pages are automatically synced and searchable. Then build a scheduled workflow that identifies stale pages not updated in 90 days and sends a Slack reminder to page owners to review them.',
    iconId: 'brand/confluence-icon',
    modules: <String>['knowledge-base', 'scheduled', 'agent', 'workflows'],
    providerId: 'confluence',
  ),
  SuggestionTemplate(
    id: 'confluence-2',
    blockType: 'confluence',
    label: 'Confluence multi-source knowledge hub',
    prompt:
        'Create a knowledge base and connect it to Confluence, Notion, and Google Drive so all my company documentation is automatically synced, chunked, and embedded. Then deploy a Q&A agent that can answer questions across all sources with citations.',
    iconId: 'emcn/search',
    modules: <String>['knowledge-base', 'scheduled', 'agent', 'workflows'],
    providerId: 'confluence',
  ),
  SuggestionTemplate(
    id: 'confluence-3',
    blockType: 'confluence',
    label: 'Confluence weekly contributor digest',
    prompt:
        'Build a scheduled workflow that aggregates the week’s new and updated Confluence pages, identifies top contributors, and posts a digest to the team Slack channel.',
    iconId: 'brand/confluence-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'confluence',
  ),
  SuggestionTemplate(
    id: 'confluence-4',
    blockType: 'confluence',
    label: 'Confluence space migration helper',
    prompt:
        'Create a workflow that takes a source Confluence space, copies pages into a target space with rewritten internal links, attachments, and labels, and writes a mapping table for redirects.',
    iconId: 'brand/confluence-icon',
    modules: <String>['files', 'tables', 'agent', 'workflows'],
    providerId: 'confluence',
  ),
  SuggestionTemplate(
    id: 'confluence-5',
    blockType: 'confluence',
    label: 'Confluence question router',
    prompt:
        'Build a workflow that watches a Confluence space for new questions, finds the right SME via labels, pings them on Slack, and updates the question page with a sourced answer once available.',
    iconId: 'brand/confluence-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'confluence',
  ),
  SuggestionTemplate(
    id: 'confluence-6',
    blockType: 'confluence',
    label: 'Confluence knowledge assistant',
    prompt:
        'Create a knowledge base synced from a Confluence space, then build a Slack agent that searches Confluence pages to answer team questions, cites the source page, and offers to create a new page when an answer is missing.',
    iconId: 'emcn/search',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
    providerId: 'confluence',
  ),
  SuggestionTemplate(
    id: 'context_dev-0',
    blockType: 'context_dev',
    label: 'Context.dev knowledge-base builder',
    prompt:
        'Build a workflow that maps a documentation site with Context.dev, crawls each page to clean markdown, chunks and embeds the content, and upserts it into a knowledge base for an answering agent.',
    iconId: 'brand/context-dev-icon',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'context_dev-1',
    blockType: 'context_dev',
    label: 'Context.dev competitor monitor',
    prompt:
        'Build a scheduled workflow that scrapes competitor pricing and changelog pages to markdown with Context.dev weekly, diffs against the prior snapshot, logs changes to a table, and posts notable updates to Slack.',
    iconId: 'brand/context-dev-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'context_dev-2',
    blockType: 'context_dev',
    label: 'Context.dev lead enrichment',
    prompt:
        'Create a workflow that takes a work email, uses Context.dev to retrieve brand data by email and classify the company into NAICS codes, and writes the enriched firmographics to a CRM record.',
    iconId: 'brand/context-dev-icon',
    modules: <String>['agent', 'tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'context_dev-3',
    blockType: 'context_dev',
    label: 'Context.dev structured data extractor',
    prompt:
        'Build a workflow that takes a website URL and a JSON schema, uses Context.dev Extract to pull structured fields across the site, and returns the validated records as JSON.',
    iconId: 'brand/context-dev-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'context_dev-4',
    blockType: 'context_dev',
    label: 'Context.dev research brief',
    prompt:
        'Create an agent that runs a Context.dev web search on a topic, scrapes the top results to markdown, and synthesizes a cited research brief saved as a file.',
    iconId: 'brand/context-dev-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'context_dev-5',
    blockType: 'context_dev',
    label: 'Context.dev design-system extractor',
    prompt:
        'Build a workflow that takes a domain, uses Context.dev to scrape its styleguide and fonts plus a homepage screenshot, and stores the design tokens and assets as files for a design handoff.',
    iconId: 'brand/context-dev-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'context_dev-6',
    blockType: 'context_dev',
    label: 'Context.dev transaction enrichment',
    prompt:
        'Create a workflow that takes raw bank transaction descriptors, uses Context.dev to identify the merchant brand behind each one, and appends the resolved company and logo to a table.',
    iconId: 'brand/context-dev-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'context_dev-7',
    blockType: 'context_dev',
    label: 'Context.dev product catalog importer',
    prompt:
        'Build a workflow that takes a brand domain, uses Context.dev to extract the brand\'s product catalog with pricing and features, and writes each product as a row in a table.',
    iconId: 'brand/context-dev-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'context_dev-8',
    blockType: 'context_dev',
    label: 'Context.dev site change watcher',
    prompt:
        'Build a scheduled workflow that maps a site sitemap with Context.dev, scrapes new or changed pages to markdown, summarizes the differences, and emails a digest.',
    iconId: 'brand/context-dev-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'convex-0',
    blockType: 'convex',
    label: 'Convex support ticket triage',
    prompt:
        'Build a workflow that runs a Convex query to fetch open support tickets, classifies each by urgency with an agent, writes the triage label back via a Convex mutation, and posts critical tickets to Slack.',
    iconId: 'brand/convex-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'convex-1',
    blockType: 'convex',
    label: 'Convex nightly backup to S3',
    prompt:
        'Create a scheduled workflow that runs each night, pages through every Convex table with List Documents, writes the exported JSON to S3 with date partitions, and records the run in an audit table.',
    iconId: 'brand/convex-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'convex-2',
    blockType: 'convex',
    label: 'Convex change-data alerting',
    prompt:
        'Build a scheduled workflow that polls Convex Document Deltas for changed rows since the last run, filters for high-value records like fraud flags or large orders, and posts an alert with context to Slack.',
    iconId: 'brand/convex-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'convex-3',
    blockType: 'convex',
    label: 'Convex user onboarding automation',
    prompt:
        'Create a workflow that receives new-signup webhooks, runs a Convex mutation to provision the user record with defaults, and sends a personalized welcome email.',
    iconId: 'brand/convex-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'convex-4',
    blockType: 'convex',
    label: 'Convex daily metrics digest',
    prompt:
        'Create a scheduled daily workflow that runs Convex queries for new signups, active users, and key feature usage, summarizes the numbers with an agent, and posts a digest to Slack with day-over-day trend.',
    iconId: 'brand/convex-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'convex-5',
    blockType: 'convex',
    label: 'Convex search index sync',
    prompt:
        'Build a scheduled workflow that uses Convex Document Deltas to mirror changed documents into an Algolia index, removes deleted documents, and writes sync lag to a tables-based monitor.',
    iconId: 'brand/convex-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'convex-6',
    blockType: 'convex',
    label: 'Convex schema drift monitor',
    prompt:
        'Create a scheduled workflow that runs Convex List Tables, diffs the returned table schemas against the last snapshot stored in a table, and notifies the engineering channel when fields are added, removed, or change type.',
    iconId: 'brand/convex-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'crowdstrike-0',
    blockType: 'crowdstrike',
    label: 'CrowdStrike alert triage',
    prompt:
        'Create a workflow that queries new high-severity CrowdStrike alerts, pulls their details, summarizes the tactic, technique, and affected host for each, posts the triage summary to Slack, and marks the reviewed alerts in progress.',
    iconId: 'brand/crowd-strike-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'crowdstrike-1',
    blockType: 'crowdstrike',
    label: 'CrowdStrike host containment',
    prompt:
        'Create a workflow that takes a host ID, contains the host in CrowdStrike, opens a Real Time Response session to capture running processes and network connections, and posts the collected evidence to Slack for the on-call responder.',
    iconId: 'brand/crowd-strike-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'crowdstrike-2',
    blockType: 'crowdstrike',
    label: 'CrowdStrike IOC sync',
    prompt:
        'Create a workflow that reads indicators of compromise from a table, creates them as custom CrowdStrike indicators with a blocking action and an expiration, and records the returned indicator IDs back to the table.',
    iconId: 'brand/crowd-strike-icon',
    modules: <String>['agent', 'tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'crowdstrike-3',
    blockType: 'crowdstrike',
    label: 'CrowdStrike vulnerability report',
    prompt:
        'Create a scheduled workflow that queries CrowdStrike Spotlight for open critical vulnerabilities, pulls the CVE and remediation details, groups them by host, and writes a prioritized remediation report for the platform team.',
    iconId: 'brand/crowd-strike-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'crowdstrike-4',
    blockType: 'crowdstrike',
    label: 'CrowdStrike case digest',
    prompt:
        'Create a scheduled workflow that queries open CrowdStrike Case Management cases, pulls each case status, severity, and assignee, and posts a daily standup digest to Slack.',
    iconId: 'brand/crowd-strike-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'crowdstrike-5',
    blockType: 'crowdstrike',
    label: 'CrowdStrike sensor coverage gaps',
    prompt:
        'Create a scheduled workflow that queries CrowdStrike Identity Protection sensors, identifies devices reporting an unprotected or degraded status, opens a PagerDuty incident for critical gaps, and posts the list to Slack.',
    iconId: 'brand/crowd-strike-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'crowdstrike-6',
    blockType: 'crowdstrike',
    label: 'CrowdStrike weekly sensor digest',
    prompt:
        'Create a scheduled weekly workflow that runs CrowdStrike sensor aggregate queries by status and OS version, summarizes coverage and unprotected counts, and writes a digest file for security leadership.',
    iconId: 'brand/crowd-strike-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'crowdstrike-7',
    blockType: 'crowdstrike',
    label: 'CrowdStrike + Okta coverage check',
    prompt:
        'Build a workflow that lists CrowdStrike Identity Protection sensors and cross-references them with Okta users and devices to find accounts active on endpoints that have no protected sensor, then writes the findings to a security table.',
    iconId: 'brand/crowd-strike-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'crowdstrike-8',
    blockType: 'crowdstrike',
    label: 'CrowdStrike asset inventory',
    prompt:
        'Create a scheduled workflow that queries CrowdStrike Identity Protection sensors per device, identifies endpoints reporting an unprotected status, and writes the gap list to a compliance table.',
    iconId: 'brand/crowd-strike-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'crowdstrike-9',
    blockType: 'crowdstrike',
    label: 'CrowdStrike stale sensor finder',
    prompt:
        'Build a scheduled workflow that queries CrowdStrike sensors, flags devices whose last heartbeat is older than a threshold, and writes the stale-sensor list to a SOC investigation table for follow-up.',
    iconId: 'brand/crowd-strike-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'crowdstrike-10',
    blockType: 'crowdstrike',
    label: 'CrowdStrike coverage report doc',
    prompt:
        'Create a scheduled workflow that aggregates CrowdStrike sensor status, OS version, and policy assignment, and generates a coverage report doc in Google Docs for the security team.',
    iconId: 'brand/crowd-strike-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'crowdstrike-11',
    blockType: 'crowdstrike',
    label: 'CrowdStrike policy drift watcher',
    prompt:
        'Build a scheduled workflow that queries CrowdStrike Identity Protection sensors, compares each device’s assigned IdP policy against the expected baseline, and writes mismatches to a SOC review queue.',
    iconId: 'brand/crowd-strike-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'crunchbase-0',
    blockType: 'crunchbase',
    label: 'Crunchbase funding round watcher',
    prompt:
        'Build a workflow that runs every morning, searches Crunchbase for funding rounds announced in the last day in my target categories, and posts each round — company, stage, amount raised, and lead investors — to a Slack channel.',
    iconId: 'brand/crunchbase-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'crunchbase-1',
    blockType: 'crunchbase',
    label: 'Crunchbase account enrichment',
    prompt:
        'Create a workflow that watches my accounts table for new company names, autocompletes each one against Crunchbase to resolve its permalink, looks up the organization, and writes headcount, headquarters, categories, and founding date back to the row.',
    iconId: 'emcn/building',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'crunchbase-2',
    blockType: 'crunchbase',
    label: 'Crunchbase ICP company list',
    prompt:
        'Build a workflow that searches Crunchbase organizations matching my ideal customer profile — category, headcount band, and headquarters region — pages through every result, and writes the company list to a table for the SDR team.',
    iconId: 'brand/crunchbase-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'crunchbase-3',
    blockType: 'crunchbase',
    label: 'Crunchbase investor portfolio brief',
    prompt:
        'Create an agent that takes an investor name, looks them up in Crunchbase, pages through their participated investments card, and writes a brief covering stage focus, check size, and the sectors they back most.',
    iconId: 'emcn/sprout',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'crunchbase-4',
    blockType: 'crunchbase',
    label: 'Crunchbase founder finder',
    prompt:
        'Build a workflow that takes a list of target companies, looks each one up in Crunchbase with the founders card, and writes every founder with their title and LinkedIn to a table so I can start outreach.',
    iconId: 'emcn/users',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'crunchbase-5',
    blockType: 'crunchbase',
    label: 'Crunchbase acquisition digest',
    prompt:
        'Create a scheduled workflow that searches Crunchbase for acquisitions announced this week in my industry, summarizes each deal — acquirer, target, price, and terms — and emails the digest to the strategy team every Friday.',
    iconId: 'brand/crunchbase-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'crunchbase-6',
    blockType: 'crunchbase',
    label: 'Crunchbase competitor tracker',
    prompt:
        'Build a workflow that takes my competitor list, looks each company up in Crunchbase, compares headcount, operating status, and latest funding against what I stored last month, and alerts me in Slack when anything changed.',
    iconId: 'emcn/search',
    modules: <String>['tables', 'scheduled', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'crunchbase-7',
    blockType: 'crunchbase',
    label: 'Crunchbase inbound lead qualifier',
    prompt:
        'Create a workflow that runs when a demo request comes in, resolves the submitted company against Crunchbase, looks up its headcount, funding stage, and category, and routes the lead to the enterprise or self-serve queue based on what it finds.',
    iconId: 'brand/crunchbase-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'crunchbase-8',
    blockType: 'crunchbase',
    label: 'Crunchbase mirror pruner',
    prompt:
        'Build a nightly workflow that reads the Crunchbase deleted-entity feed for organizations and people, matches each deletion against my mirrored companies table, and removes or tombstones the rows that no longer exist upstream.',
    iconId: 'emcn/trash',
    modules: <String>['tables', 'scheduled', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'crunchbase-9',
    blockType: 'crunchbase',
    label: 'Crunchbase query builder',
    prompt:
        'Create an agent that lists the fields a Crunchbase collection publishes, turns a plain-English request like "European fintechs that raised a Series B last quarter" into the matching search predicates, runs the search, and returns the results.',
    iconId: 'emcn/list-checks',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cursor-0',
    blockType: 'cursor',
    label: 'Cursor cloud agent launcher',
    prompt:
        'Build a workflow that takes a feature description and a GitHub repository, launches a Cursor cloud agent with structured instructions, polls until the agent finishes, captures the generated pull request link, and posts a summary to Slack so the team can review.',
    iconId: 'brand/cursor-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cursor-1',
    blockType: 'cursor',
    label: 'Cursor issue-to-PR pipeline',
    prompt:
        'Create a workflow that fires when a GitHub issue is labeled "auto-fix", crafts a precise prompt from the issue description, launches a Cursor cloud agent on the repository, monitors progress, and comments on the issue with the resulting pull request and conversation summary.',
    iconId: 'brand/cursor-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cursor-2',
    blockType: 'cursor',
    label: 'Cursor agent fleet monitor',
    prompt:
        'Build a scheduled workflow that runs every fifteen minutes, lists all active Cursor cloud agents, logs status, runtime, and repository to a tracking table, and posts a daily Slack summary of completed, failing, and long-running agents.',
    iconId: 'brand/cursor-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cursor-3',
    blockType: 'cursor',
    label: 'Cursor test-fix delegator',
    prompt:
        'Build a workflow triggered by a failing GitHub Actions test run that extracts the failing test name and error, launches a targeted Cursor cloud agent to fix only that test, downloads the artifact diff when ready, and replies on the failed run with the proposed patch.',
    iconId: 'brand/cursor-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cursor-4',
    blockType: 'cursor',
    label: 'Cursor refactor follow-up loop',
    prompt:
        'Create a workflow that picks up review comments on a Cursor-authored pull request, formulates each comment as a follow-up instruction, sends them to the originating Cursor cloud agent, and waits for the updated diff before re-requesting review.',
    iconId: 'brand/cursor-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cursor-5',
    blockType: 'cursor',
    label: 'Cursor agent conversation archiver',
    prompt:
        'Build a scheduled daily workflow that lists completed Cursor cloud agents, fetches each conversation history, stores the transcripts and produced artifacts as files, and updates a tracking table with prompts, durations, and outcomes for retrospective analysis.',
    iconId: 'brand/cursor-icon',
    modules: <String>['scheduled', 'files', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'cursor-6',
    blockType: 'cursor',
    label: 'Cursor stuck-agent cleaner',
    prompt:
        'Create a scheduled workflow that runs hourly, lists Cursor cloud agents, detects agents stuck in the same state longer than a configurable threshold, stops or deletes them based on rules, and posts a Slack report of the cleanup actions taken.',
    iconId: 'brand/cursor-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dagster-0',
    blockType: 'dagster',
    label: 'Dagster pipeline status digest',
    prompt:
        'Create a scheduled daily workflow that pulls Dagster run statuses for the previous day, identifies failed and skipped runs, and posts a digest with links to the worst offenders in Slack.',
    iconId: 'brand/dagster-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dagster-1',
    blockType: 'dagster',
    label: 'Dagster asset freshness watcher',
    prompt:
        'Build a scheduled workflow that polls Dagster assets, checks each critical asset’s latest materialization timestamp against a freshness threshold, alerts when an asset becomes stale, and opens a Linear ticket for the data-platform team.',
    iconId: 'brand/dagster-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dagster-2',
    blockType: 'dagster',
    label: 'Dagster job kickoff orchestrator',
    prompt:
        'Create a workflow that triggers a Dagster job with run parameters when an upstream condition is satisfied, polls until completion, and writes the run outcome to a control table.',
    iconId: 'brand/dagster-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dagster-3',
    blockType: 'dagster',
    label: 'Dagster cost dashboard',
    prompt:
        'Build a scheduled weekly workflow that pulls Dagster run durations, calculates compute cost per pipeline, and writes a weekly cost dashboard to a finance review file.',
    iconId: 'brand/dagster-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dagster-4',
    blockType: 'dagster',
    label: 'Dagster lineage map',
    prompt:
        'Create a workflow that exports Dagster asset lineage into a graph database for cross-pipeline impact analysis when an upstream source schema changes.',
    iconId: 'brand/dagster-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dagster-5',
    blockType: 'dagster',
    label: 'Dagster sensor health watcher',
    prompt:
        'Build a scheduled workflow that lists Dagster sensors, checks their tick history, and alerts Slack when a sensor stops emitting ticks unexpectedly.',
    iconId: 'brand/dagster-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dagster-6',
    blockType: 'dagster',
    label: 'Dagster + Databricks coordinator',
    prompt:
        'Create a workflow that orchestrates a Dagster job that triggers a Databricks notebook, waits for completion, captures outputs, and writes the unified run history to a tracking table.',
    iconId: 'brand/dagster-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'databricks-0',
    blockType: 'databricks',
    label: 'Databricks job runner',
    prompt:
        'Build a scheduled workflow that triggers a Databricks job daily, polls until completion, writes the run status and metrics to a control table, and pages on failure.',
    iconId: 'brand/databricks-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'databricks-1',
    blockType: 'databricks',
    label: 'Databricks cluster cost guard',
    prompt:
        'Create a scheduled workflow that lists Databricks clusters hourly, flags clusters that are running while idle, and posts a Slack alert with the candidates to shut down so the platform team can reclaim spend.',
    iconId: 'brand/databricks-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'databricks-2',
    blockType: 'databricks',
    label: 'Databricks notebook scheduler',
    prompt:
        'Build a workflow that runs a parameterized Databricks notebook, captures the outputs as files, and posts the result to a chosen Slack channel for review.',
    iconId: 'brand/databricks-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'databricks-3',
    blockType: 'databricks',
    label: 'Databricks ML feature freshness',
    prompt:
        'Create a scheduled workflow that runs SQL against Databricks feature tables to check the latest update timestamp per feature, alerts when a critical feature has stale data, and writes the alert details to a tracking table.',
    iconId: 'brand/databricks-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'databricks-4',
    blockType: 'databricks',
    label: 'Databricks model evaluator',
    prompt:
        'Build a workflow that runs a Databricks ML model evaluation job on the latest data, captures the metrics, writes results to a model-registry table, and pings Slack on regression.',
    iconId: 'brand/databricks-icon',
    modules: <String>['agent', 'tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'databricks-5',
    blockType: 'databricks',
    label: 'Databricks Delta Lake compactor',
    prompt:
        'Create a scheduled workflow that runs OPTIMIZE and VACUUM on Databricks Delta Lake tables weekly, captures the size and performance delta, and writes a maintenance report.',
    iconId: 'brand/databricks-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'databricks-6',
    blockType: 'databricks',
    label: 'Databricks job failure watcher',
    prompt:
        'Build a workflow that lists recent Databricks job runs every 15 minutes, detects failed runs, pulls the run output and error for an agent to summarize the likely cause, and posts an actionable Slack alert with a link to the run.',
    iconId: 'brand/databricks-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'databricks-7',
    blockType: 'databricks',
    label: 'Databricks Genie Slack analyst',
    prompt:
        'Build an agent that answers data questions asked in a Slack channel with Databricks Genie. It keeps one Genie conversation per Slack thread in a table so follow-up questions keep their context, then replies in the thread with the answer, a short table of the result rows, and the SQL Genie ran.',
    iconId: 'brand/databricks-icon',
    modules: <String>['agent', 'tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'databricks-8',
    blockType: 'databricks',
    label: 'Databricks Genie space router',
    prompt:
        'Create an agent that lists the Databricks Genie spaces I can access, picks the space whose title and description best fit each incoming question, asks that Genie space, and posts the answer to Slack with which space answered it.',
    iconId: 'brand/databricks-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'databricks-9',
    blockType: 'databricks',
    label: 'Databricks Genie KPI digest',
    prompt:
        'Build a scheduled workflow that asks a Databricks Genie agent every Monday for a research report on last week\'s key business metrics and what drove them, then posts the report and the SQL behind it to a Slack channel.',
    iconId: 'brand/databricks-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'datadog-0',
    blockType: 'datadog',
    label: 'Datadog infra health report',
    prompt:
        'Create a scheduled daily workflow that queries Datadog for key infrastructure metrics — error rates, latency percentiles, CPU and memory usage — logs them to a table for trend tracking, and sends a morning Slack report highlighting any anomalies or degradations.',
    iconId: 'brand/datadog-icon',
    modules: <String>['tables', 'scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'datadog-1',
    blockType: 'datadog',
    label: 'Datadog alert-to-Linear bridge',
    prompt:
        'Build a scheduled workflow that polls Datadog monitors for any in an alerting state, classifies severity, creates a Linear ticket for non-paging issues with full context, and posts a Slack notification linking both.',
    iconId: 'brand/datadog-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'datadog-2',
    blockType: 'datadog',
    label: 'Datadog SLO weekly review',
    prompt:
        'Create a scheduled weekly workflow that queries Datadog timeseries for the key reliability metrics behind each service SLO, computes error budget burn, and writes a narrative review file for the SRE team to discuss in the weekly meeting.',
    iconId: 'brand/datadog-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'datadog-3',
    blockType: 'datadog',
    label: 'Datadog cost optimizer',
    prompt:
        'Build a scheduled workflow that queries Datadog estimated-usage timeseries for the top custom metrics by volume, writes optimization recommendations to a finance review file, and pings the platform team.',
    iconId: 'brand/datadog-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'datadog-4',
    blockType: 'datadog',
    label: 'Datadog monitor config backup',
    prompt:
        'Create a scheduled workflow that lists every Datadog monitor nightly, fetches each monitor’s full configuration, exports the definitions as JSON to S3 with version history, and writes a manifest to a tracking table for restore drills.',
    iconId: 'brand/datadog-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'datadog-5',
    blockType: 'datadog',
    label: 'Datadog deploy guardrail',
    prompt:
        'Build a workflow triggered after a deploy that creates a Datadog event marker, queries error-rate and latency timeseries over the next few minutes, and pages the team via PagerDuty if the metrics breach the rollback threshold.',
    iconId: 'brand/datadog-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'datadog-6',
    blockType: 'datadog',
    label: 'Datadog SLO weekly report',
    prompt:
        'Create a scheduled weekly workflow that queries Datadog timeseries for key service SLOs, lists which monitors fired during the week, writes the SLO compliance numbers to a table, and emails an availability summary to the on-call leads.',
    iconId: 'brand/datadog-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'daytona-0',
    blockType: 'daytona',
    label: 'Daytona code interpreter',
    prompt:
        'Build a workflow where an agent answers data questions by writing Python, creating a Daytona sandbox, running the code in it, and replying with the computed result and any printed output.',
    iconId: 'brand/daytona-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'daytona-1',
    blockType: 'daytona',
    label: 'Daytona PR test runner',
    prompt:
        'Create a workflow triggered by a GitHub pull request that creates a Daytona sandbox, clones the repository at the PR branch, runs the test suite with an execute command, and posts the pass/fail summary back to the PR.',
    iconId: 'brand/daytona-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'daytona-2',
    blockType: 'daytona',
    label: 'Daytona CSV analysis',
    prompt:
        'Build a workflow that takes an uploaded CSV file, uploads it into a Daytona sandbox, runs a Python analysis script over it, downloads the generated report file, and shares the findings in Slack.',
    iconId: 'brand/daytona-icon',
    modules: <String>['files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'daytona-3',
    blockType: 'daytona',
    label: 'Daytona scheduled script runner',
    prompt:
        'Create a scheduled daily workflow that spins up a Daytona sandbox, runs a maintenance script with an execute command, writes the output to a results table, and deletes the sandbox when finished.',
    iconId: 'brand/daytona-icon',
    modules: <String>['scheduled', 'tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'daytona-4',
    blockType: 'daytona',
    label: 'Daytona sandbox janitor',
    prompt:
        'Build a scheduled weekly workflow that lists all Daytona sandboxes, stops any that have been running longer than expected, deletes sandboxes labeled as temporary, and posts a cleanup summary to Slack.',
    iconId: 'brand/daytona-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'daytona-5',
    blockType: 'daytona',
    label: 'Daytona generated-code validator',
    prompt:
        'Create a workflow where an agent generates code from a user request, runs it in a Daytona sandbox, inspects the exit code and output, fixes errors and reruns until the code passes, then returns the validated code.',
    iconId: 'brand/daytona-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'daytona-6',
    blockType: 'daytona',
    label: 'Daytona repo health check',
    prompt:
        'Build a scheduled workflow that creates a Daytona sandbox, clones the main branch of a repository, runs install and build commands, records any failures in a table, and alerts the engineering channel when the build breaks.',
    iconId: 'brand/daytona-icon',
    modules: <String>['scheduled', 'tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'daytona-7',
    blockType: 'daytona',
    label: 'Daytona file transformer',
    prompt:
        'Create a workflow that receives a document from a form, uploads it to a Daytona sandbox, runs a conversion script on it, downloads the transformed file, and emails it back to the requester.',
    iconId: 'brand/daytona-icon',
    modules: <String>['files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'devin-0',
    blockType: 'devin',
    label: 'Devin session launcher',
    prompt:
        'Build a workflow that accepts a coding task description, creates a new Devin session with rich context, polls the session until it produces a pull request or hits a blocker, and posts the session link and status to Slack.',
    iconId: 'brand/devin-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'devin-1',
    blockType: 'devin',
    label: 'Devin bug-fix dispatcher',
    prompt:
        'Create a workflow that watches for new critical errors, packages the stack trace and reproduction steps into a Devin prompt, creates a session, and updates a Linear ticket with the Devin session link and any pull requests it opens.',
    iconId: 'brand/devin-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'devin-2',
    blockType: 'devin',
    label: 'Devin session monitor',
    prompt:
        'Build a scheduled workflow that runs every ten minutes, lists Devin sessions for your organization, tracks status changes, logs sessions, pull requests, and tags to a table, and sends a Slack alert when any session has been stuck for more than two hours.',
    iconId: 'brand/devin-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'devin-3',
    blockType: 'devin',
    label: 'Devin progress nudger',
    prompt:
        'Build a workflow that runs every hour against active Devin sessions, detects sessions that are suspended or awaiting input, sends a targeted follow-up message via the Devin API to unblock progress, and notifies the requester if a session needs human intervention.',
    iconId: 'brand/devin-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'devin-4',
    blockType: 'devin',
    label: 'Devin documentation gap closer',
    prompt:
        'Create a workflow that scans a knowledge base of docs against the latest repo state, finds undocumented public APIs, opens a Devin session for each gap with a prompt to write documentation, and stores the produced markdown back into the knowledge base.',
    iconId: 'brand/devin-icon',
    modules: <String>['knowledge-base', 'files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'devin-5',
    blockType: 'devin',
    label: 'Devin retrospective report',
    prompt:
        'Build a scheduled weekly workflow that lists Devin sessions completed in the past week, summarizes outcomes, pull requests merged, time-to-completion, and recurring failure modes, and writes a retrospective report file shared with engineering leadership.',
    iconId: 'brand/devin-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'devin-6',
    blockType: 'devin',
    label: 'Devin issue-to-PR runner',
    prompt:
        'Create a workflow triggered when a Linear issue is labeled ready-for-devin that creates a Devin session with the issue context, monitors the session to completion, and comments the resulting pull request link back on the Linear issue.',
    iconId: 'brand/devin-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'discord-0',
    blockType: 'discord',
    label: 'Discord community manager',
    prompt:
        'Create a knowledge base connected to my Google Docs or Notion with product documentation. Then build a workflow that monitors my Discord server for unanswered questions, answers them using the knowledge base, tracks common questions in a table, and sends a weekly community summary to Slack.',
    iconId: 'brand/discord-icon',
    modules: <String>[
      'knowledge-base',
      'tables',
      'agent',
      'scheduled',
      'workflows',
    ],
  ),
  SuggestionTemplate(
    id: 'discord-1',
    blockType: 'discord',
    label: 'Discord support deflector',
    prompt:
        'Build a scheduled workflow that polls help channels in Discord for new questions, searches a knowledge base for an answer, and posts a sourced reply in-thread; escalates to a human when confidence is low.',
    iconId: 'brand/discord-icon',
    modules: <String>['knowledge-base', 'scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'discord-2',
    blockType: 'discord',
    label: 'Discord weekly community digest',
    prompt:
        'Create a scheduled weekly workflow that summarizes Discord activity — top threads, helpful members, new questions — and posts the digest to the announcements channel and Slack.',
    iconId: 'brand/discord-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'discord-3',
    blockType: 'discord',
    label: 'Discord onboarding tracker',
    prompt:
        'Build a scheduled workflow that polls a Discord server for recently joined members, opens a private onboarding thread for each new member with relevant links, and tracks completion of starter tasks in a table.',
    iconId: 'brand/discord-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'discord-4',
    blockType: 'discord',
    label: 'Discord moderation triage',
    prompt:
        'Create a scheduled workflow that polls Discord channels for new messages, classifies community-guideline violations with an agent, auto-warns the user on minor issues, and pings moderators in a private channel for severe cases.',
    iconId: 'brand/discord-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'discord-5',
    blockType: 'discord',
    label: 'Discord feature request collector',
    prompt:
        'Build a scheduled workflow that polls a Discord feedback channel for new posts, classifies them as bugs vs feature requests, opens Linear tickets for actionable items, and replies in-thread with the ticket link.',
    iconId: 'brand/discord-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'discord-6',
    blockType: 'discord',
    label: 'Discord event reminder',
    prompt:
        'Create a scheduled workflow that reads upcoming Luma or Google Calendar events, posts a reminder in the matching Discord channel 24 hours before, and pings RSVP attendees by role.',
    iconId: 'brand/discord-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'docusign-0',
    blockType: 'docusign',
    label: 'DocuSign envelope sender',
    prompt:
        'Build a workflow that takes a deal from Salesforce above a threshold, pre-fills a DocuSign envelope from a template, sends it, and writes the envelope ID back to the opportunity.',
    iconId: 'brand/docu-sign-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'docusign',
  ),
  SuggestionTemplate(
    id: 'docusign-1',
    blockType: 'docusign',
    label: 'DocuSign chase reminder',
    prompt:
        'Create a scheduled workflow that lists DocuSign envelopes pending signature for over 48 hours, notifies the owning rep in Slack to nudge each signer, and escalates with a flagged message after 7 days.',
    iconId: 'brand/docu-sign-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'docusign',
  ),
  SuggestionTemplate(
    id: 'docusign-2',
    blockType: 'docusign',
    label: 'DocuSign completed contract archiver',
    prompt:
        'Build a scheduled workflow that polls DocuSign for completed envelopes, downloads the signed PDF, saves it to a Google Drive contracts folder, and writes the metadata into a contracts table.',
    iconId: 'brand/docu-sign-icon',
    modules: <String>['scheduled', 'files', 'tables', 'agent', 'workflows'],
    providerId: 'docusign',
  ),
  SuggestionTemplate(
    id: 'docusign-3',
    blockType: 'docusign',
    label: 'DocuSign clause analyzer',
    prompt:
        'Create a workflow that processes signed DocuSign contracts, extracts payment terms, liability caps, and renewal dates, writes them to a table, and flags non-standard clauses for legal review.',
    iconId: 'brand/docu-sign-icon',
    modules: <String>['files', 'tables', 'agent', 'workflows'],
    providerId: 'docusign',
  ),
  SuggestionTemplate(
    id: 'docusign-4',
    blockType: 'docusign',
    label: 'DocuSign renewal tracker',
    prompt:
        'Build a scheduled workflow that reads a DocuSign contracts table, finds renewals due in the next 60 days, and creates a renewal-prep task in Salesforce for each.',
    iconId: 'brand/docu-sign-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'docusign',
  ),
  SuggestionTemplate(
    id: 'docusign-5',
    blockType: 'docusign',
    label: 'DocuSign stalled envelope resolver',
    prompt:
        'Create a scheduled workflow that lists in-flight DocuSign envelopes, checks each envelope’s recipients for signers who have left the company, voids the affected envelopes, and posts the list to Slack so a rep can resend from the right template.',
    iconId: 'brand/docu-sign-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'docusign',
  ),
  SuggestionTemplate(
    id: 'docusign-6',
    blockType: 'docusign',
    label: 'DocuSign signature analytics digest',
    prompt:
        'Build a scheduled weekly workflow that pulls DocuSign envelope analytics — time-to-sign, completion rate, drop-off — and posts a digest to the sales ops Slack channel.',
    iconId: 'brand/docu-sign-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'docusign',
  ),
  SuggestionTemplate(
    id: 'downdetector-0',
    blockType: 'downdetector',
    label: 'Downdetector outage alerter',
    prompt:
        'Build a scheduled workflow that checks the Downdetector status of my critical vendors every 15 minutes and posts a Slack alert whenever any of them flips to a "danger" (outage) status.',
    iconId: 'brand/downdetector-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'downdetector-1',
    blockType: 'downdetector',
    label: 'Downdetector incident logger',
    prompt:
        'Create a scheduled workflow that pulls active Downdetector incidents for my key services hourly and appends new incidents to a tables-based incident log with start time, peak user impact, and total reports.',
    iconId: 'brand/downdetector-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'downdetector-2',
    blockType: 'downdetector',
    label: 'Downdetector report-spike watcher',
    prompt:
        'Build a scheduled workflow that fetches the last hour of Downdetector reports for a company slug, compares the latest bucket against the company baseline, and emails me when reports spike well above baseline.',
    iconId: 'brand/downdetector-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'downdetector-3',
    blockType: 'downdetector',
    label: 'Downdetector root-cause summarizer',
    prompt:
        'Create a workflow that, given a company id, pulls the current Downdetector status and top problem indicators and has an agent summarize what users are most likely experiencing right now.',
    iconId: 'brand/downdetector-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'downdetector-4',
    blockType: 'downdetector',
    label: 'Downdetector vendor status digest',
    prompt:
        'Build a scheduled daily workflow that searches Downdetector for each of my vendors, reads their current status and 24h report stats, writes a status digest table, and posts a Slack summary.',
    iconId: 'brand/downdetector-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'downdetector-5',
    blockType: 'downdetector',
    label: 'Downdetector support deflection',
    prompt:
        'Create a workflow triggered when a support ticket arrives that checks the Downdetector status of the affected service and, if there is a confirmed outage, replies to the customer that the issue is a known provider outage.',
    iconId: 'brand/downdetector-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'downdetector-6',
    blockType: 'downdetector',
    label: 'Downdetector competitor outage tracker',
    prompt:
        'Build a scheduled workflow that lists all active Downdetector incidents across a category, filters to my competitors, and logs their outages to a table so the team can track reliability over time.',
    iconId: 'brand/downdetector-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dropbox-0',
    blockType: 'dropbox',
    label: 'Dropbox to knowledge base',
    prompt:
        'Build a scheduled workflow that lists a Dropbox folder, downloads documents added since the last run, extracts and chunks their text, and upserts the chunks into a knowledge base for agent retrieval.',
    iconId: 'brand/dropbox-icon',
    modules: <String>[
      'scheduled',
      'knowledge-base',
      'files',
      'agent',
      'workflows',
    ],
    providerId: 'dropbox',
  ),
  SuggestionTemplate(
    id: 'dropbox-1',
    blockType: 'dropbox',
    label: 'Dropbox shared-link auditor',
    prompt:
        'Create a scheduled workflow that lists Dropbox shared links, identifies links shared with external users or marked public, and writes a security review report to a table.',
    iconId: 'brand/dropbox-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'dropbox',
  ),
  SuggestionTemplate(
    id: 'dropbox-2',
    blockType: 'dropbox',
    label: 'Dropbox vendor-invoice intake',
    prompt:
        'Build a scheduled workflow that lists a Dropbox vendor folder for invoice PDFs added since the last run, extracts vendor and amount with an agent, writes the row to a payables table, and pings finance on Slack.',
    iconId: 'brand/dropbox-icon',
    modules: <String>['scheduled', 'files', 'tables', 'agent', 'workflows'],
    providerId: 'dropbox',
  ),
  SuggestionTemplate(
    id: 'dropbox-3',
    blockType: 'dropbox',
    label: 'Dropbox creative asset organizer',
    prompt:
        'Create a scheduled workflow that lists a Dropbox creative-assets folder, classifies files added since the last run by campaign and type, moves them into the right subfolder, and updates a tables-based asset index.',
    iconId: 'brand/dropbox-icon',
    modules: <String>['scheduled', 'files', 'tables', 'agent', 'workflows'],
    providerId: 'dropbox',
  ),
  SuggestionTemplate(
    id: 'dropbox-4',
    blockType: 'dropbox',
    label: 'Dropbox retention sweeper',
    prompt:
        'Build a scheduled workflow that finds Dropbox files older than the retention policy, archives them to long-term storage, and writes the cleanup record to an audit table.',
    iconId: 'brand/dropbox-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'dropbox',
  ),
  SuggestionTemplate(
    id: 'dropbox-5',
    blockType: 'dropbox',
    label: 'Dropbox to Notion publisher',
    prompt:
        'Create a scheduled workflow that lists Dropbox markdown files added since the last run, converts each to a Notion page in the right database, and writes a link back to the source file metadata.',
    iconId: 'brand/dropbox-icon',
    modules: <String>['scheduled', 'files', 'agent', 'workflows'],
    providerId: 'dropbox',
  ),
  SuggestionTemplate(
    id: 'dropbox-6',
    blockType: 'dropbox',
    label: 'Dropbox + DocuSign signed-doc archiver',
    prompt:
        'Build a scheduled workflow that polls DocuSign for completed envelopes, downloads each signed PDF, saves it to a Dropbox compliance folder, and writes the audit record to a contracts table.',
    iconId: 'brand/dropbox-icon',
    modules: <String>['scheduled', 'files', 'tables', 'agent', 'workflows'],
    providerId: 'dropbox',
  ),
  SuggestionTemplate(
    id: 'dspy-0',
    blockType: 'dspy',
    label: 'DSPy structured extraction',
    prompt:
        'Build a workflow that reads raw records from a table, runs a DSPy predict program on your self-hosted server to extract structured fields from each, and writes the typed results back to the table.',
    iconId: 'brand/ds-py-icon',
    modules: <String>['tables', 'files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dspy-1',
    blockType: 'dspy',
    label: 'DSPy evaluation harness',
    prompt:
        'Create a workflow that runs a DSPy program against a labeled evals table, computes accuracy, F1, and per-class breakdowns, and writes the metrics to a reporting table for tracking over iterations.',
    iconId: 'brand/ds-py-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dspy-2',
    blockType: 'dspy',
    label: 'DSPy A/B program selector',
    prompt:
        'Create a scheduled workflow that runs two DSPy program endpoints against the same eval set nightly, scores each on accuracy, and writes the head-to-head comparison and recommended winner to a table.',
    iconId: 'brand/ds-py-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dspy-3',
    blockType: 'dspy',
    label: 'DSPy production traffic replay',
    prompt:
        'Build a workflow that periodically replays sample production traces through a DSPy program, captures divergences, and writes regression analysis to a tracking file.',
    iconId: 'brand/ds-py-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dspy-4',
    blockType: 'dspy',
    label: 'DSPy + LangSmith trace harness',
    prompt:
        'Create a workflow that runs a DSPy program over an eval set, logs each prediction as a LangSmith trace for evaluation, captures the quality delta against the previous run, and writes the comparison to engineering Slack.',
    iconId: 'brand/ds-py-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dspy-5',
    blockType: 'dspy',
    label: 'DSPy ticket classifier',
    prompt:
        'Build a workflow that runs new support tickets through a DSPy predict signature to classify category, urgency, and sentiment with structured outputs, then routes each ticket to the right queue and writes the labels back to the ticket.',
    iconId: 'brand/ds-py-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dspy-6',
    blockType: 'dspy',
    label: 'DSPy reasoning research agent',
    prompt:
        'Create a workflow that takes a research question, uses DSPy chain-of-thought to break it into sub-questions, runs DSPy ReAct with web search to gather evidence, and writes a structured, cited answer to a file.',
    iconId: 'brand/ds-py-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dub-0',
    blockType: 'dub',
    label: 'Dub short link factory',
    prompt:
        'Build a workflow that takes a destination URL and campaign metadata, creates a tracked short link in Dub with UTM parameters and a custom slug, stores the link in a table, and returns it to the caller for use in outreach and marketing.',
    iconId: 'brand/dub-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dub-1',
    blockType: 'dub',
    label: 'Dub campaign link batcher',
    prompt:
        'Create a workflow that reads a table of campaign destinations, upserts a Dub short link for each row with consistent UTM tags, writes the resulting short URL back into the table, and posts a Slack confirmation summarizing how many links were created or refreshed.',
    iconId: 'brand/dub-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dub-2',
    blockType: 'dub',
    label: 'Dub analytics digest',
    prompt:
        'Build a scheduled weekly workflow that pulls Dub link analytics — clicks, leads, sales, and top referrers — for active campaigns, writes a narrative summary highlighting winners and decliners, and delivers the digest to Slack with deep links into the Dub dashboard.',
    iconId: 'brand/dub-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dub-3',
    blockType: 'dub',
    label: 'Dub link hygiene auditor',
    prompt:
        'Create a scheduled monthly workflow that lists all Dub links, checks each destination for 4xx and 5xx responses, flags broken links in a table, and emails the marketing team a remediation list so dead campaign links never go live.',
    iconId: 'brand/dub-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dub-4',
    blockType: 'dub',
    label: 'Dub outbound link personalizer',
    prompt:
        'Build a workflow that reads a leads table, generates a per-lead Dub short link with the lead identifier in UTM and metadata, attaches the personalized link to the outreach email body, and tracks delivery in the table.',
    iconId: 'brand/dub-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dub-5',
    blockType: 'dub',
    label: 'Dub release announcement linker',
    prompt:
        'Create a workflow triggered by a GitHub release that creates a Dub short link for the release notes URL, posts the short link to the marketing Slack channel, and stores the mapping of release tag to short link in a tracking table.',
    iconId: 'brand/dub-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dub-6',
    blockType: 'dub',
    label: 'Dub top-converting links report',
    prompt:
        'Build a scheduled monthly workflow that pulls Dub analytics grouped by link, ranks top performers by leads and sales, identifies underperformers, writes a narrative report file with recommendations, and shares it with marketing leadership.',
    iconId: 'brand/dub-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'duckduckgo-0',
    blockType: 'duckduckgo',
    label: 'DuckDuckGo private research agent',
    prompt:
        'Build an agent that runs DuckDuckGo searches for queries that need privacy preservation, returns answers with citations, and saves the findings to a knowledge base.',
    iconId: 'brand/duck-duck-go-icon',
    modules: <String>['agent', 'knowledge-base', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'duckduckgo-1',
    blockType: 'duckduckgo',
    label: 'DuckDuckGo daily digest',
    prompt:
        'Create a scheduled daily workflow that queries DuckDuckGo for topics I follow, summarizes the top hits with citations, and posts a digest to Slack.',
    iconId: 'brand/duck-duck-go-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'duckduckgo-2',
    blockType: 'duckduckgo',
    label: 'DuckDuckGo competitor watcher',
    prompt:
        'Build a scheduled workflow that runs DuckDuckGo searches for competitor mentions weekly, scores each by relevance, and writes a competitive log to a table.',
    iconId: 'brand/duck-duck-go-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'duckduckgo-3',
    blockType: 'duckduckgo',
    label: 'DuckDuckGo agent fallback',
    prompt:
        'Create an agent that uses Perplexity for primary search and falls back to DuckDuckGo on rate-limit errors so research workflows remain reliable.',
    iconId: 'brand/duck-duck-go-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'duckduckgo-4',
    blockType: 'duckduckgo',
    label: 'DuckDuckGo legal-research helper',
    prompt:
        'Build a workflow that uses DuckDuckGo to find precedents and analyses for legal questions, summarizes with citations, and writes a research file for review.',
    iconId: 'brand/duck-duck-go-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'duckduckgo-5',
    blockType: 'duckduckgo',
    label: 'DuckDuckGo open-web validator',
    prompt:
        'Create a workflow that validates claims in an agent draft by searching DuckDuckGo for supporting sources, flagging claims without strong citations.',
    iconId: 'brand/duck-duck-go-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'duckduckgo-6',
    blockType: 'duckduckgo',
    label: 'DuckDuckGo enrichment researcher',
    prompt:
        'Build a workflow that uses DuckDuckGo to research prospect or company context where standard enrichment is missing, and writes the findings back to the CRM record.',
    iconId: 'brand/duck-duck-go-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dynamodb-0',
    blockType: 'dynamodb',
    label: 'DynamoDB hot-partition watcher',
    prompt:
        'Build a scheduled workflow that pulls DynamoDB CloudWatch metrics, identifies hot partitions and throttled requests, and writes the report to a Slack channel with mitigation suggestions.',
    iconId: 'brand/dynamo-db-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dynamodb-1',
    blockType: 'dynamodb',
    label: 'DynamoDB TTL backfill',
    prompt:
        'Create a workflow that scans a DynamoDB table for items missing the TTL attribute, computes the correct TTL based on creation time, and updates in batches with throttling.',
    iconId: 'brand/dynamo-db-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dynamodb-2',
    blockType: 'dynamodb',
    label: 'DynamoDB to S3 archive',
    prompt:
        'Build a scheduled workflow that exports DynamoDB items older than the retention horizon to S3 with Parquet partitioning and removes the rows from the table, writing the archive manifest.',
    iconId: 'brand/dynamo-db-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dynamodb-3',
    blockType: 'dynamodb',
    label: 'DynamoDB change publisher',
    prompt:
        'Create a scheduled workflow that scans a DynamoDB table for items changed since the last run, transforms each into a typed event, and publishes it to an SQS queue for downstream processing.',
    iconId: 'brand/dynamo-db-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dynamodb-4',
    blockType: 'dynamodb',
    label: 'DynamoDB capacity recommender',
    prompt:
        'Build a scheduled weekly workflow that analyzes DynamoDB capacity consumption, recommends switches between provisioned and on-demand per table, and writes the savings projection to a finance review file.',
    iconId: 'brand/dynamo-db-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dynamodb-5',
    blockType: 'dynamodb',
    label: 'DynamoDB GSI health audit',
    prompt:
        'Create a scheduled workflow that scans DynamoDB GSIs for skew, low projection efficiency, and unused indexes, and writes a remediation plan to engineering Slack.',
    iconId: 'brand/dynamo-db-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dynamodb-6',
    blockType: 'dynamodb',
    label: 'DynamoDB + Athena unified analytics',
    prompt:
        'Create a workflow that exports DynamoDB tables nightly into Athena-queryable Parquet, registers the schema, and writes a sample query for analyst use.',
    iconId: 'brand/dynamo-db-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dynatrace-0',
    blockType: 'dynatrace',
    label: 'Dynatrace problem triage',
    prompt:
        'Build a scheduled workflow that polls Dynatrace every five minutes for open problems, pulls the root cause entity and recent logs for each one, summarizes the likely cause with an agent, and posts the enriched problem to Slack and PagerDuty.',
    iconId: 'brand/dynatrace-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dynatrace-1',
    blockType: 'dynatrace',
    label: 'Dynatrace deploy marker',
    prompt:
        'Create a workflow that runs when a GitHub release is published and ingests a CUSTOM_DEPLOYMENT event into Dynatrace with the version, commit, and service entity selector, so metric changes can be correlated with the deploy.',
    iconId: 'brand/dynatrace-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dynatrace-2',
    blockType: 'dynatrace',
    label: 'Dynatrace SLO burn-rate watch',
    prompt:
        'Build a scheduled hourly workflow that reads Dynatrace SLOs, flags any with a fast error-budget burn rate, and opens a Linear issue with the SLO name, remaining budget, and time to exhaustion.',
    iconId: 'brand/dynatrace-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dynatrace-3',
    blockType: 'dynatrace',
    label: 'Dynatrace vulnerability digest',
    prompt:
        'Create a scheduled daily workflow that lists open critical and high Dynatrace security problems, groups them by affected service and CVE, writes them to a Sim table, and posts a remediation digest to the security channel in Slack.',
    iconId: 'brand/dynatrace-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dynatrace-4',
    blockType: 'dynatrace',
    label: 'Dynatrace capacity report',
    prompt:
        'Build a scheduled weekly workflow that queries Dynatrace host CPU, memory, and disk metrics per management zone, ranks the most saturated hosts, and writes a capacity planning report to a Sim table.',
    iconId: 'brand/dynatrace-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dynatrace-5',
    blockType: 'dynatrace',
    label: 'Dynatrace log error triage',
    prompt:
        'Create a scheduled workflow that searches Dynatrace logs for new error patterns in the last fifteen minutes, clusters them by message shape with an agent, and posts only the previously unseen clusters to Slack.',
    iconId: 'brand/dynatrace-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dynatrace-6',
    blockType: 'dynatrace',
    label: 'Dynatrace auto-close on recovery',
    prompt:
        'Build a scheduled workflow that checks Dynatrace problems whose entities have returned to a healthy metric baseline, closes them with an explanatory comment, and records what was closed in a Sim table for review.',
    iconId: 'brand/dynatrace-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'dynatrace-7',
    blockType: 'dynatrace',
    label: 'Dynatrace config audit',
    prompt:
        'Create a scheduled weekly workflow that reads the Dynatrace audit log for configuration changes, highlights changes made outside business hours or by service accounts, and emails a compliance summary to the platform team.',
    iconId: 'brand/dynatrace-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'elasticsearch-0',
    blockType: 'elasticsearch',
    label: 'Elasticsearch log triage',
    prompt:
        'Build a scheduled workflow that runs saved Elasticsearch queries hourly for error patterns, clusters the matches, writes the top groups to a triage table, and pings on-call.',
    iconId: 'brand/elasticsearch-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'elasticsearch-1',
    blockType: 'elasticsearch',
    label: 'Elasticsearch security event correlator',
    prompt:
        'Create a workflow that pulls Elasticsearch security events, correlates them across sources, and opens a CrowdStrike or PagerDuty incident on a confirmed pattern.',
    iconId: 'brand/elasticsearch-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'elasticsearch-2',
    blockType: 'elasticsearch',
    label: 'Elasticsearch index lifecycle audit',
    prompt:
        'Build a scheduled weekly workflow that audits Elasticsearch indices against retention policies, identifies over-retained data, and writes the cleanup plan to a Slack approval thread.',
    iconId: 'brand/elasticsearch-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'elasticsearch-3',
    blockType: 'elasticsearch',
    label: 'Elasticsearch search-as-a-service connector',
    prompt:
        'Create a workflow that exposes a saved Elasticsearch query as an internal search endpoint, normalizes results into a standard shape, and writes usage telemetry to a table.',
    iconId: 'brand/elasticsearch-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'elasticsearch-4',
    blockType: 'elasticsearch',
    label: 'Elasticsearch + knowledge base hybrid',
    prompt:
        'Build a workflow that combines Elasticsearch keyword search with a vector knowledge base, fuses results with reciprocal-rank fusion, and answers user questions with grounded citations.',
    iconId: 'brand/elasticsearch-icon',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'elasticsearch-5',
    blockType: 'elasticsearch',
    label: 'Elasticsearch slow-query digest',
    prompt:
        'Create a scheduled daily workflow that aggregates Elasticsearch slow-log entries, clusters the top offenders, and posts a digest to the platform Slack channel with recommended fixes.',
    iconId: 'brand/elasticsearch-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'elasticsearch-6',
    blockType: 'elasticsearch',
    label: 'Elasticsearch + LangSmith retrieval evaluator',
    prompt:
        'Create a workflow that uses LangSmith to evaluate retrieval quality from Elasticsearch versus a vector knowledge base, writes the head-to-head scores to a table.',
    iconId: 'brand/elasticsearch-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'elevenlabs-0',
    blockType: 'elevenlabs',
    label: 'ElevenLabs blog-to-podcast',
    prompt:
        'Build a workflow that takes a blog post, narrates it with an ElevenLabs voice, saves the audio file, and posts a player-ready link to the marketing Slack channel.',
    iconId: 'brand/eleven-labs-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'elevenlabs-1',
    blockType: 'elevenlabs',
    label: 'ElevenLabs voice greeting generator',
    prompt:
        'Create a workflow that reads a table of new enterprise customers, generates a personalized ElevenLabs voice greeting with their account manager voice, and emails the audio file to the customer on day one.',
    iconId: 'brand/eleven-labs-icon',
    modules: <String>['tables', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'elevenlabs-2',
    blockType: 'elevenlabs',
    label: 'ElevenLabs IVR builder',
    prompt:
        'Build a workflow that generates branded ElevenLabs voice prompts from a tables-driven script, saves each clip as a file, and lists the bundle so it can be wired into the phone tree.',
    iconId: 'brand/eleven-labs-icon',
    modules: <String>['tables', 'files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'elevenlabs-3',
    blockType: 'elevenlabs',
    label: 'ElevenLabs + Pulse meeting voice digest',
    prompt:
        'Build a workflow that takes Pulse meeting insights, narrates them with an ElevenLabs voice, and emails the audio digest to the team for asynchronous review.',
    iconId: 'brand/eleven-labs-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'elevenlabs-4',
    blockType: 'elevenlabs',
    label: 'ElevenLabs daily voice digest',
    prompt:
        'Build a scheduled daily workflow that generates an ElevenLabs voice digest of the day’s key metrics, saves the audio, and Slacks the player link to leadership.',
    iconId: 'brand/eleven-labs-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'elevenlabs-5',
    blockType: 'elevenlabs',
    label: 'ElevenLabs release-notes narrator',
    prompt:
        'Create a workflow that takes new product release notes, rewrites them into a natural spoken script with an agent, generates narration with ElevenLabs text-to-speech, and saves the audio file ready to share as a what\'s-new update.',
    iconId: 'brand/eleven-labs-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'elevenlabs-6',
    blockType: 'elevenlabs',
    label: 'ElevenLabs voicemail responder',
    prompt:
        'Build a workflow that on a new inbound message drafts a short personalized reply with an agent, converts it to speech with ElevenLabs in a chosen voice, and saves the audio so it can be sent as a voice note to the customer.',
    iconId: 'brand/eleven-labs-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'emailbison-0',
    blockType: 'emailbison',
    label: 'Email Bison campaign launcher',
    prompt:
        'Build a workflow that takes a target persona and offer, drafts a multi-step Email Bison campaign with personalized variables, creates the campaign and attaches the matching leads, and launches it once a human approves.',
    iconId: 'brand/email-bison-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'emailbison-1',
    blockType: 'emailbison',
    label: 'Email Bison reply triage',
    prompt:
        'Create a workflow that pulls new Email Bison replies on a schedule, classifies each as interested, not interested, objection, or out-of-office, applies the matching tag to the lead, and pings the rep in Slack for hot replies.',
    iconId: 'brand/email-bison-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'emailbison-2',
    blockType: 'emailbison',
    label: 'Email Bison + Apollo lead feeder',
    prompt:
        'Build a workflow that runs an Apollo search for an ICP, enriches each prospect, creates the lead in Email Bison with personalization variables, and attaches the leads to the matching active campaign.',
    iconId: 'brand/email-bison-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'emailbison-3',
    blockType: 'emailbison',
    label: 'Email Bison tag automator',
    prompt:
        'Create a workflow that reads Email Bison replies and activity, and applies tags to leads based on engagement signals — opened, clicked, replied positively, bounced — so segmentation stays current for follow-up campaigns.',
    iconId: 'brand/email-bison-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'emailbison-4',
    blockType: 'emailbison',
    label: 'Email Bison weekly outbound digest',
    prompt:
        'Build a scheduled weekly workflow that pulls Email Bison campaign performance — sends, opens, replies, positive reply rate — generates a digest with the top campaigns and bottom performers, and posts it to a Slack sales channel.',
    iconId: 'brand/email-bison-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'emailbison-5',
    blockType: 'emailbison',
    label: 'Email Bison + HubSpot sync',
    prompt:
        'Create a workflow that mirrors Email Bison lead status and reply outcomes into the matching HubSpot contact, logs each campaign step as an engagement, and creates a HubSpot task for sales when a lead replies positively.',
    iconId: 'brand/email-bison-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'emailbison-6',
    blockType: 'emailbison',
    label: 'Email Bison bounce cleanup',
    prompt:
        'Build a scheduled workflow that finds Email Bison leads with hard bounces, tags them for suppression, updates the lead in Email Bison, and writes a cleanup report so deliverability stays healthy.',
    iconId: 'brand/email-bison-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'embeddings-0',
    blockType: 'embeddings',
    label: 'Document embedding pipeline',
    prompt:
        'Build a workflow that watches a files folder, chunks each new document, generates embeddings, and upserts vectors into Pinecone with rich metadata for retrieval.',
    iconId: 'brand/embeddings-icon',
    modules: <String>['files', 'knowledge-base', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'embeddings-1',
    blockType: 'embeddings',
    label: 'Knowledge base re-embedder',
    prompt:
        'Create a scheduled workflow that finds documents whose embeddings are stale, regenerates them, and re-upserts the vectors into Pinecone so retrieval stays current.',
    iconId: 'brand/embeddings-icon',
    modules: <String>['scheduled', 'knowledge-base', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'embeddings-2',
    blockType: 'embeddings',
    label: 'Semantic duplicate detector',
    prompt:
        'Build a workflow that reads new rows from a table, generates an embedding for each, compares them against existing rows by cosine similarity, and flags near-duplicates in an evaluation table.',
    iconId: 'brand/embeddings-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'embeddings-3',
    blockType: 'embeddings',
    label: 'Product catalog semantic search',
    prompt:
        'Create a workflow that embeds each product description from a table, upserts the vectors into Pinecone, and lets an incoming query return the closest matching products by similarity.',
    iconId: 'brand/embeddings-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'embeddings-4',
    blockType: 'embeddings',
    label: 'Semantic ticket deduplication',
    prompt:
        'Build a workflow that embeds each new support ticket, searches a Pinecone index of past tickets for near-duplicates, and links the new ticket to the matching thread instead of opening a fresh one.',
    iconId: 'brand/embeddings-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'embeddings-5',
    blockType: 'embeddings',
    label: 'FAQ semantic router',
    prompt:
        'Create a workflow that embeds an incoming question, compares it against embedded FAQ entries to find the closest match, and returns the canned answer when similarity is high or escalates to an agent when it is not.',
    iconId: 'brand/embeddings-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'embeddings-6',
    blockType: 'embeddings',
    label: 'Embedding-based content clustering',
    prompt:
        'Build a scheduled workflow that pulls recent feedback from a table, generates embeddings for each entry, clusters them by semantic similarity, and writes the themed groups with representative quotes back to a summary table.',
    iconId: 'brand/embeddings-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'enrich-0',
    blockType: 'enrich',
    label: 'Enrich CRM hydrator',
    prompt:
        'Build a workflow that watches new Salesforce leads, enriches each with Enrich.so contact data, and writes role, company size, and email to the lead record.',
    iconId: 'brand/enrich-so-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'enrich-1',
    blockType: 'enrich',
    label: 'Enrich list cleaner',
    prompt:
        'Create a workflow that runs an outreach list through Enrich, removes invalid emails and disqualified roles, and writes the clean list to a sender table.',
    iconId: 'brand/enrich-so-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'enrich-2',
    blockType: 'enrich',
    label: 'Enrich bulk-account researcher',
    prompt:
        'Build a workflow that takes a list of target accounts, enriches each with Enrich firmographic data, and writes a tables-based account brief for the sales team.',
    iconId: 'brand/enrich-so-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'enrich-3',
    blockType: 'enrich',
    label: 'Enrich + Email Bison sender',
    prompt:
        'Create a workflow that runs Enrich on prospects then drafts and sends a personalized Email Bison sequence based on the enriched fields.',
    iconId: 'brand/enrich-so-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'enrich-4',
    blockType: 'enrich',
    label: 'Enrich event-attendee researcher',
    prompt:
        'Build a workflow that takes the Luma event attendee list, enriches each via Enrich, and writes a per-attendee research brief for the sales team.',
    iconId: 'brand/enrich-so-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'enrich-5',
    blockType: 'enrich',
    label: 'Enrich CRM gap-filler',
    prompt:
        'Create a scheduled workflow that finds HubSpot contacts missing key fields, runs Enrich, and fills in the gaps so reporting is complete.',
    iconId: 'brand/enrich-so-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'enrich-6',
    blockType: 'enrich',
    label: 'Enrich LinkedIn role validator',
    prompt:
        'Build a scheduled workflow that reads HubSpot contacts with a LinkedIn profile URL, re-enriches each with Enrich, flags outdated roles, and updates the contact record with the current title.',
    iconId: 'brand/enrich-so-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'exa-0',
    blockType: 'exa',
    label: 'Exa company intel agent',
    prompt:
        'Build an agent that takes a company name, uses the Exa Agent operation to find recent product updates, funding news, and competitor mentions, and writes a one-page intel brief.',
    iconId: 'brand/exa-ai-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'exa-1',
    blockType: 'exa',
    label: 'Exa knowledge crawler',
    prompt:
        'Build a workflow that uses Exa to find authoritative URLs on a topic, scrapes each one, chunks the content, and upserts it into a knowledge base so the agent can answer with citations.',
    iconId: 'brand/exa-ai-icon',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'exa-2',
    blockType: 'exa',
    label: 'Exa deep research agent',
    prompt:
        'Build an agent that uses Exa deep search to find authoritative sources on a topic, scrapes them, and produces a structured research brief with citations.',
    iconId: 'brand/exa-ai-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'exa-3',
    blockType: 'exa',
    label: 'Exa similar-page finder',
    prompt:
        'Create a workflow that takes a URL, runs an Exa search to find related authoritative sources, and writes the discovery list to a research table.',
    iconId: 'brand/exa-ai-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'exa-4',
    blockType: 'exa',
    label: 'Exa daily research digest',
    prompt:
        'Build a scheduled workflow that runs Exa searches on tracked topics each morning, summarizes top hits with citations, and emails the user a research digest.',
    iconId: 'brand/exa-ai-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'exa-5',
    blockType: 'exa',
    label: 'Exa investment research helper',
    prompt:
        'Create an agent that uses the Exa Agent operation to deep-research a ticker, finds recent material developments, summarizes with citations, and writes the brief to a finance research file.',
    iconId: 'brand/exa-ai-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'exa-6',
    blockType: 'exa',
    label: 'Exa competitor news monitor',
    prompt:
        'Build a scheduled daily workflow that runs Exa search for fresh news about my competitors, gets the page contents and finds similar coverage, summarizes the notable moves with citations, and posts a digest to the team Slack channel.',
    iconId: 'brand/exa-ai-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'extend-0',
    blockType: 'extend',
    label: 'Extend structured-data extractor',
    prompt:
        'Build a workflow that runs uploaded forms through Extend to pull labelled fields, writes the structured rows to a table, and notifies Slack on missing required fields.',
    iconId: 'brand/extend-icon',
    modules: <String>['tables', 'files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'extend-1',
    blockType: 'extend',
    label: 'Extend insurance claim ingester',
    prompt:
        'Create a workflow that uses Extend to ingest claim forms, extracts policy number, claim amount, and incident details to structured rows, and routes high-value claims to a Slack adjuster channel.',
    iconId: 'brand/extend-icon',
    modules: <String>['tables', 'files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'extend-2',
    blockType: 'extend',
    label: 'Extend purchase-order extractor',
    prompt:
        'Create a workflow that processes inbound PO PDFs with Extend, writes vendor, SKU, quantity, and total to an orders table, and pings Slack when a PO exceeds the approval threshold.',
    iconId: 'brand/extend-icon',
    modules: <String>['tables', 'files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'extend-3',
    blockType: 'extend',
    label: 'Extend + ElevenLabs spoken-summary',
    prompt:
        'Build a workflow that uses Extend to pull structured data from a document, then narrates the summary with ElevenLabs, producing an audio briefing for stakeholders.',
    iconId: 'brand/extend-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'extend-4',
    blockType: 'extend',
    label: 'Extend KYC pipeline',
    prompt:
        'Build a workflow that runs Extend on uploaded KYC documents, validates extracted fields against a compliance rule set, and writes outcomes to a verification table.',
    iconId: 'brand/extend-icon',
    modules: <String>['files', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'extend-5',
    blockType: 'extend',
    label: 'Extend invoice processor',
    prompt:
        'Create a workflow that parses uploaded vendor invoices with Extend, extracts line items, totals, and due dates, validates against the matching purchase order, and writes approved invoices to an accounts-payable table for payment.',
    iconId: 'brand/extend-icon',
    modules: <String>['files', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'extend-6',
    blockType: 'extend',
    label: 'Extend contract data extractor',
    prompt:
        'Build a workflow that runs Extend on uploaded contracts to pull parties, term dates, renewal clauses, and obligations, summarizes the key risks with an agent, and logs the structured fields to a contracts table for the legal team.',
    iconId: 'brand/extend-icon',
    modules: <String>['files', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'fathom-0',
    blockType: 'fathom',
    label: 'Fathom meeting recap to Slack',
    prompt:
        'Build a workflow that triggers when a Fathom meeting completes, pulls the summary and action items, and posts a recap to the relevant Slack channel.',
    iconId: 'brand/fathom-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'fathom-1',
    blockType: 'fathom',
    label: 'Fathom transcript to Notion notes',
    prompt:
        'Create a workflow that triggers on a new Fathom meeting, pulls the transcript and summary, and writes a structured meeting note to Notion with attendees and next steps.',
    iconId: 'brand/fathom-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'fathom-2',
    blockType: 'fathom',
    label: 'Fathom weekly meeting digest',
    prompt:
        'Build a scheduled weekly workflow that lists Fathom meetings from the past week, summarizes the key decisions and commitments across calls with an agent, and emails the digest to the team.',
    iconId: 'brand/fathom-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'fathom-3',
    blockType: 'fathom',
    label: 'Fathom CRM call logger',
    prompt:
        'Build a workflow that triggers when a Fathom meeting ends, pulls the summary and CRM matches, and logs the call notes and next steps to the matched HubSpot contact.',
    iconId: 'brand/fathom-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'fathom-4',
    blockType: 'fathom',
    label: 'Fathom action-item tracker',
    prompt:
        'Create a workflow that triggers on a new Fathom meeting, extracts action items from the summary with an agent, and writes each one to a tasks table with owner and due date.',
    iconId: 'brand/fathom-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'fathom-5',
    blockType: 'fathom',
    label: 'Fathom meeting archive',
    prompt:
        'Build a workflow that triggers on a completed Fathom meeting, pulls the full transcript and summary, and saves a formatted recap file to the shared meeting archive.',
    iconId: 'brand/fathom-icon',
    modules: <String>['files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'fathom-6',
    blockType: 'fathom',
    label: 'Fathom sales-call action items',
    prompt:
        'Create a workflow that after a Fathom meeting pulls the summary and transcript, extracts the customer commitments and next steps with an agent, creates follow-up tasks in the CRM, and emails a recap to the attendees.',
    iconId: 'brand/fathom-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'findymail-0',
    blockType: 'findymail',
    label: 'Findymail email finder',
    prompt:
        'Build a workflow that takes a prospect name and company domain from a table, runs Findymail to find the verified work email, and writes the deliverable contact back to the row.',
    iconId: 'brand/findymail-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'findymail-1',
    blockType: 'findymail',
    label: 'Findymail LinkedIn enricher',
    prompt:
        'Create a workflow that takes a list of LinkedIn profile URLs, finds the matching verified work email via Findymail, and writes the enriched contacts into a research table.',
    iconId: 'brand/findymail-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'findymail-2',
    blockType: 'findymail',
    label: 'Findymail email verifier',
    prompt:
        'Build a workflow that runs a list of email addresses through Findymail verification, removes undeliverable addresses, and writes a clean list for outbound sends.',
    iconId: 'brand/findymail-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'findymail-3',
    blockType: 'findymail',
    label: 'Findymail company team mapper',
    prompt:
        'Create a workflow that takes a target company domain, uses Findymail to find employees by job title and enrich company data, and writes the org map into a tables-based account base.',
    iconId: 'brand/findymail-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'findymail-4',
    blockType: 'findymail',
    label: 'Findymail CRM gap-filler',
    prompt:
        'Build a scheduled workflow that finds HubSpot contacts missing verified emails, looks them up with Findymail, verifies each, and updates the contact record.',
    iconId: 'brand/findymail-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'findymail-5',
    blockType: 'findymail',
    label: 'Findymail LinkedIn list builder',
    prompt:
        'Create a workflow that reads a list of LinkedIn profile URLs from a table, finds and verifies each prospect\'s work email and phone with Findymail, enriches their company, and writes a clean, ready-to-contact prospect table.',
    iconId: 'brand/findymail-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'findymail-6',
    blockType: 'findymail',
    label: 'Findymail domain prospecting',
    prompt:
        'Build a workflow that takes a target company domain, uses Findymail to find employees and their verified emails by role, validates each address, and pushes the qualified contacts into the outbound sequence.',
    iconId: 'brand/findymail-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'firecrawl-0',
    blockType: 'firecrawl',
    label: 'Firecrawl keyword brief generator',
    prompt:
        'Build a workflow that takes a target keyword, uses Firecrawl to scrape the top 10 ranking pages, analyzes their content structure and subtopics, then generates a detailed content brief with outline, word count target, questions to answer, and internal linking suggestions.',
    iconId: 'brand/firecrawl-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'firecrawl-1',
    blockType: 'firecrawl',
    label: 'Firecrawl competitor change tracker',
    prompt:
        'Build a scheduled workflow that scrapes competitor websites, pricing pages, and changelog pages weekly using Firecrawl, compares against previous snapshots, summarizes any changes, logs them to a tracking table, and sends a Slack alert for major updates.',
    iconId: 'brand/firecrawl-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'firecrawl-2',
    blockType: 'firecrawl',
    label: 'Firecrawl competitor site monitor',
    prompt:
        'Build a scheduled workflow that uses Firecrawl to scrape competitor pricing, product, and changelog pages weekly, diffs against the prior snapshot, and posts changes to Slack.',
    iconId: 'brand/firecrawl-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'firecrawl-3',
    blockType: 'firecrawl',
    label: 'Firecrawl SEO content brief',
    prompt:
        'Create a workflow that takes a target keyword, scrapes the top-10 ranking pages with Firecrawl, analyzes structure and subtopics, and writes a content brief file.',
    iconId: 'brand/firecrawl-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'firecrawl-4',
    blockType: 'firecrawl',
    label: 'Firecrawl knowledge-base builder',
    prompt:
        'Build a workflow that crawls a documentation site with Firecrawl, chunks and embeds the pages, and upserts them into a knowledge base for an answering agent.',
    iconId: 'brand/firecrawl-icon',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'firecrawl-5',
    blockType: 'firecrawl',
    label: 'Firecrawl + Exa research stack',
    prompt:
        'Create an agent that uses Exa to find authoritative URLs on a topic, scrapes each with Firecrawl, and produces a structured research brief with citations.',
    iconId: 'brand/firecrawl-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'firecrawl-6',
    blockType: 'firecrawl',
    label: 'Firecrawl product-launch detector',
    prompt:
        'Build a scheduled workflow that crawls competitor blogs and product pages with Firecrawl daily, classifies posts as product launches, and posts notable launches to Slack.',
    iconId: 'brand/firecrawl-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'fireflies-0',
    blockType: 'fireflies',
    label: 'Fireflies meeting recap to Slack',
    prompt:
        'Build a workflow that runs when a Fireflies recording finishes, pulls the transcript, summarizes decisions and action items, and posts the recap to the linked Slack channel.',
    iconId: 'brand/fireflies-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'fireflies-1',
    blockType: 'fireflies',
    label: 'Fireflies CRM updater',
    prompt:
        'Create a workflow that runs after a Fireflies sales call, summarizes objections and next steps, and updates the linked Salesforce or HubSpot opportunity.',
    iconId: 'brand/fireflies-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'fireflies-2',
    blockType: 'fireflies',
    label: 'Fireflies action-item ticket creator',
    prompt:
        'Build a workflow that extracts action items from a Fireflies meeting transcript, creates Linear or Asana tasks for each with owners and due dates, and posts a summary to Slack.',
    iconId: 'brand/fireflies-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'fireflies-3',
    blockType: 'fireflies',
    label: 'Fireflies customer-quote miner',
    prompt:
        'Create a workflow that processes Fireflies transcripts for customer interview calls, extracts notable quotes and themes, and writes them to a marketing research table.',
    iconId: 'brand/fireflies-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'fireflies-4',
    blockType: 'fireflies',
    label: 'Fireflies talk-ratio coach',
    prompt:
        'Build a scheduled weekly workflow that pulls Fireflies sales-call analytics per rep — talk ratio, longest monologue, question rate — and posts a coaching digest to managers.',
    iconId: 'brand/fireflies-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'fireflies-5',
    blockType: 'fireflies',
    label: 'Fireflies + Notion meeting notes',
    prompt:
        'Create a workflow that watches Fireflies recordings, generates a polished meeting-notes page in Notion under the right team space, and links the recording.',
    iconId: 'brand/fireflies-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'fireflies-6',
    blockType: 'fireflies',
    label: 'Fireflies competitor-mention tracker',
    prompt:
        'Build a workflow that scans Fireflies sales transcripts for competitor mentions, logs the context and outcome to a competitive-intel table, and posts notable patterns to Slack weekly.',
    iconId: 'brand/fireflies-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'fivetran-0',
    blockType: 'fivetran',
    label: 'Failed sync triage',
    prompt:
        'Build a workflow triggered when a Fivetran sync ends with a failure that reads the connection, its active warnings, and the last day of sync history, has an agent explain the likely cause and fix, and posts the summary to the data team in Slack.',
    iconId: 'brand/fivetran-icon',
    modules: <String>['agent', 'workflows'],
    featured: true,
    providerId: 'fivetran',
  ),
  SuggestionTemplate(
    id: 'fivetran-1',
    blockType: 'fivetran',
    label: 'Security log ingestion monitor',
    prompt:
        'Create a scheduled workflow that lists the Fivetran connections feeding security logs from sources like Okta into Databricks, flags any that are paused, broken, or delayed, and opens a Jira ticket for each one so the SIEM pipeline never silently goes stale.',
    iconId: 'brand/fivetran-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'fivetran',
  ),
  SuggestionTemplate(
    id: 'fivetran-2',
    blockType: 'fivetran',
    label: 'Run dbt after a sync',
    prompt:
        'Build a workflow that runs when a Fivetran sync finishes successfully and starts the matching Fivetran transformation, then reports when the transformation succeeds or fails.',
    iconId: 'brand/fivetran-icon',
    modules: <String>['workflows'],
    providerId: 'fivetran',
  ),
  SuggestionTemplate(
    id: 'fivetran-3',
    blockType: 'fivetran',
    label: 'Daily pipeline health digest',
    prompt:
        'Create a scheduled daily workflow that lists every Fivetran connection, collects its sync history and data volumes for the last day, and emails the data team a digest of failures, delays, and the largest loads.',
    iconId: 'brand/fivetran-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'fivetran',
  ),
  SuggestionTemplate(
    id: 'fivetran-4',
    blockType: 'fivetran',
    label: 'Connection change audit log',
    prompt:
        'Build a workflow triggered by Fivetran connection created, edited, paused, resumed, and deleted events that records who changed what and when in a table, for a change-management audit trail.',
    iconId: 'brand/fivetran-icon',
    modules: <String>['tables', 'workflows'],
    providerId: 'fivetran',
  ),
  SuggestionTemplate(
    id: 'fivetran-5',
    blockType: 'fivetran',
    label: 'Fivetran access review',
    prompt:
        'Create a scheduled monthly workflow that lists Fivetran users and service accounts, flags suspended accounts that still have API keys and users who have not logged in for 90 days, and writes the review to a table for the security team.',
    iconId: 'brand/fivetran-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'fivetran',
  ),
  SuggestionTemplate(
    id: 'fivetran-6',
    blockType: 'fivetran',
    label: 'Self-serve source onboarding',
    prompt:
        'Build a workflow that takes a requested source type and team, creates a paused Fivetran connection in the right group, generates a Connect Card link, and sends it to the requester in Slack so they can authorize the source themselves.',
    iconId: 'brand/fivetran-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'fivetran',
  ),
  SuggestionTemplate(
    id: 'flint-0',
    blockType: 'flint',
    label: 'Flint programmatic SEO pages',
    prompt:
        'Build a workflow that reads a table of target keywords and customer data, then uses Flint to generate a landing page for each row from a template page, publishing them automatically.',
    iconId: 'brand/flint-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'flint-1',
    blockType: 'flint',
    label: 'Flint case-study generator',
    prompt:
        'Create a workflow triggered when a deal is marked closed-won that pulls the customer details, drafts case-study context with an agent, and uses Flint to generate a case-study page from the template.',
    iconId: 'brand/flint-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'flint-2',
    blockType: 'flint',
    label: 'Flint site update from Slack',
    prompt:
        'Build a workflow triggered by a Slack message in the #website channel that turns the request into a Flint agent task prompt, starts the task, and replies in the thread with the task ID.',
    iconId: 'brand/flint-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'flint-3',
    blockType: 'flint',
    label: 'Flint task status monitor',
    prompt:
        'Create a scheduled workflow that reads pending Flint task IDs from a table, checks each task status with Flint, writes preview and published URLs back to the row when completed, and flags failures.',
    iconId: 'brand/flint-icon',
    modules: <String>['scheduled', 'tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'flint-4',
    blockType: 'flint',
    label: 'Flint changelog page publisher',
    prompt:
        'Build a workflow triggered when a new release is tagged in GitHub that summarizes the changes with an agent and starts a Flint task to add the release notes to the changelog page, publishing on completion.',
    iconId: 'brand/flint-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'flint-5',
    blockType: 'flint',
    label: 'Flint failed-task alerts',
    prompt:
        'Create a workflow that checks a Flint task status and, when the task has failed, posts the task ID and error message to a Slack channel so the team can rerun it.',
    iconId: 'brand/flint-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'flint-6',
    blockType: 'flint',
    label: 'Flint location pages from a spreadsheet',
    prompt:
        'Build a workflow that reads city and service data from Google Sheets and uses Flint to generate a local landing page per city from a template, then writes each published URL back to the sheet.',
    iconId: 'brand/flint-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'flint-7',
    blockType: 'flint',
    label: 'Flint content refresh agent',
    prompt:
        'Create a scheduled workflow that reviews outdated pages listed in a table, drafts updated copy instructions with an agent, and starts a Flint task per page to refresh the content without publishing until reviewed.',
    iconId: 'brand/flint-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'gamma-0',
    blockType: 'gamma',
    label: 'Gamma deck from doc',
    prompt:
        'Build a workflow that takes a Google Docs source, generates a Gamma deck from the structure and bullet points, and emails the deck link to the author for polish.',
    iconId: 'brand/gamma-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'gamma-1',
    blockType: 'gamma',
    label: 'Gamma customer-story builder',
    prompt:
        'Create a workflow that takes a customer-story brief, generates a Gamma deck with the challenge, solution, results, and pull quote, and shares the link with the marketing team in Slack.',
    iconId: 'brand/gamma-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'gamma-2',
    blockType: 'gamma',
    label: 'Gamma weekly all-hands deck',
    prompt:
        'Build a scheduled weekly workflow that pulls KPIs from tables, generates a Gamma all-hands deck with the latest numbers, and posts the link to the leadership Slack channel.',
    iconId: 'brand/gamma-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'gamma-3',
    blockType: 'gamma',
    label: 'Gamma onboarding training',
    prompt:
        'Create a workflow that generates a Gamma onboarding training deck from a knowledge base topic, including interactive quizzes at the end, and shares it with the new hire.',
    iconId: 'brand/gamma-icon',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'gamma-4',
    blockType: 'gamma',
    label: 'Gamma sales pitch personalizer',
    prompt:
        'Build a workflow triggered by a Salesforce opportunity that generates a Gamma sales pitch deck personalized to the account, embeds the deck link in the opportunity, and notifies the rep.',
    iconId: 'brand/gamma-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'gamma-5',
    blockType: 'gamma',
    label: 'Gamma weekly content carousel',
    prompt:
        'Create a scheduled workflow that turns the week’s top blog posts into a multi-slide Gamma carousel, then queues the export for X and LinkedIn posting.',
    iconId: 'brand/gamma-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'gamma-6',
    blockType: 'gamma',
    label: 'Gamma RFP responder',
    prompt:
        'Build a workflow that takes an inbound RFP, generates a Gamma response deck using a knowledge base of past proposals, and attaches the deck link to the linked HubSpot deal.',
    iconId: 'brand/gamma-icon',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'github-0',
    blockType: 'github',
    label: 'GitHub PR review assistant',
    prompt:
        'Create a knowledge base connected to my GitHub repo so it stays synced with my style guide and coding standards. Then build a workflow that reviews new pull requests against it, checks for common issues and security vulnerabilities, and posts a review comment with specific suggestions.',
    iconId: 'brand/github-icon',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'github-1',
    blockType: 'github',
    label: 'GitHub changelog generator',
    prompt:
        'Build a scheduled workflow that runs every Friday, pulls all merged PRs from GitHub for the week, categorizes changes as features, fixes, or improvements, and generates a user-facing changelog document with clear descriptions.',
    iconId: 'brand/github-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'github-2',
    blockType: 'github',
    label: 'GitHub docs auto-updater',
    prompt:
        'Create a knowledge base connected to my GitHub repository so code and docs stay synced. Then build a scheduled weekly workflow that detects API changes, compares them against the knowledge base to find outdated documentation, and either updates Notion pages directly or creates Linear tickets for the needed changes.',
    iconId: 'brand/github-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'github-3',
    blockType: 'github',
    label: 'GitHub repository search',
    prompt:
        'Create a knowledge base connected to my GitHub repository so all source files, READMEs, and pull request descriptions are automatically synced and searchable. Then build an agent I can ask things like "where do we handle Stripe webhooks?" or "what changed in the auth module last month?" and get answers with file and PR citations.',
    iconId: 'brand/github-icon',
    modules: <String>['knowledge-base', 'agent'],
  ),
  SuggestionTemplate(
    id: 'github-4',
    blockType: 'github',
    label: 'GitHub release notes drafter',
    prompt:
        'Build a workflow triggered when a GitHub release tag is created. Pull every merged pull request and commit since the previous tag, group them by feature, fix, and chore, draft customer-facing release notes, and post the draft as a comment on the release for final approval.',
    iconId: 'brand/github-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'github-5',
    blockType: 'github',
    label: 'GitHub weekly team digest',
    prompt:
        'Build a scheduled workflow that runs every Friday, pulls the week\'s GitHub commits, closed Linear issues, and key Slack conversations, then emails a formatted weekly summary to the team.',
    iconId: 'emcn/calendar',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'github-6',
    blockType: 'github',
    label: 'Link GitHub pull requests to Jira tickets',
    prompt:
        'Build a workflow that monitors GitHub pull requests and automatically transitions linked Jira issues when PRs are opened or merged, keeping your project board accurate without any manual updates.',
    iconId: 'brand/github-icon',
    modules: <String>['agent', 'workflows'],
    featured: true,
  ),
  SuggestionTemplate(
    id: 'github-7',
    blockType: 'github',
    label: 'Sync GitHub events with Linear issues',
    prompt:
        'Build a workflow that creates Linear issues from GitHub pull requests and commits, and automatically updates their status when a PR is merged.',
    iconId: 'brand/github-icon',
    modules: <String>['agent', 'workflows'],
    featured: true,
  ),
  SuggestionTemplate(
    id: 'github-8',
    blockType: 'github',
    label: 'Get GitHub activity alerts in Slack',
    prompt:
        'Create an agent that watches GitHub for new pull requests, commits, issues, or deployments and posts formatted Slack notifications so your engineering team never misses a critical event.',
    iconId: 'brand/github-icon',
    modules: <String>['agent', 'workflows'],
    featured: true,
  ),
  SuggestionTemplate(
    id: 'gitlab-0',
    blockType: 'gitlab',
    label: 'GitLab merge request reviewer',
    prompt:
        'Create a knowledge base from my coding standards and architecture docs. Build a scheduled workflow that lists open GitLab merge requests, fetches each diff, runs an agent that checks the code against the knowledge base and flags security issues, performance concerns, and style violations, then posts a structured review as an MR comment.',
    iconId: 'brand/git-lab-icon',
    modules: <String>['scheduled', 'knowledge-base', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'gitlab-1',
    blockType: 'gitlab',
    label: 'GitLab pipeline failure responder',
    prompt:
        'Build a scheduled workflow that lists recent GitLab pipelines on the main branch, finds newly failed runs, summarizes the root cause from the job logs, identifies the most likely owner from recent commits, opens a GitLab issue with the diagnosis, and posts an alert to Slack with a link to the failing pipeline.',
    iconId: 'brand/git-lab-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'gitlab-2',
    blockType: 'gitlab',
    label: 'GitLab issue triager',
    prompt:
        'Create a scheduled workflow that runs every hour, pulls new GitLab issues, classifies each by component, severity, and effort, applies labels and assigns the right owner, and posts a daily Slack digest of unassigned and stale issues so nothing slips through.',
    iconId: 'brand/git-lab-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'gitlab-3',
    blockType: 'gitlab',
    label: 'GitLab release publisher',
    prompt:
        'Build a scheduled workflow that detects new GitLab release tags, gathers merged merge requests since the previous tag, groups changes by component, drafts release notes as a file, and posts the formatted summary back as a comment on the release.',
    iconId: 'brand/git-lab-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'gitlab-4',
    blockType: 'gitlab',
    label: 'GitLab project health digest',
    prompt:
        'Create a scheduled weekly workflow that pulls open issues, stale merge requests, recent pipeline failures, and contributor activity for every GitLab project, logs metrics to a tracking table, and sends a Slack health digest to engineering leadership.',
    iconId: 'brand/git-lab-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'gitlab-5',
    blockType: 'gitlab',
    label: 'GitLab merge request unblocker',
    prompt:
        'Build a scheduled daily workflow that lists open GitLab merge requests, identifies those blocked on review for more than two days, sends targeted Slack DMs to the assigned reviewers with the MR link, and updates a table tracking unblock actions.',
    iconId: 'brand/git-lab-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'gitlab-6',
    blockType: 'gitlab',
    label: 'GitLab access governance agent',
    prompt:
        'Build a scheduled workflow that lists pending GitLab access requests and invitations across our key groups, checks each requester against a table of approved teams, approves or denies the access requests at the right access level, revokes stale invitations older than 14 days, and posts a summary of every access decision to Slack.',
    iconId: 'brand/git-lab-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'gitlab-7',
    blockType: 'gitlab',
    label: 'GitLab repository knowledge base',
    prompt:
        'Create a knowledge base that ingests GitLab project files, merge request descriptions, and issue threads, then build an agent I can ask things like "how does the billing module handle proration?" or "which MR introduced the rate limiter?" and get answers with GitLab citations.',
    iconId: 'brand/git-lab-icon',
    modules: <String>['knowledge-base', 'agent'],
  ),
  SuggestionTemplate(
    id: 'gmail-0',
    blockType: 'gmail',
    label: 'Gmail auto-reply agent',
    prompt:
        'Create a workflow that reads my Gmail inbox, identifies emails that need a response, and drafts contextual replies for each one. Schedule it to run every hour.',
    iconId: 'brand/gmail-icon',
    modules: <String>['agent', 'workflows'],
    featured: true,
    popular: true,
    providerId: 'google-email',
  ),
  SuggestionTemplate(
    id: 'gmail-1',
    blockType: 'gmail',
    label: 'Gmail outbound sequence builder',
    prompt:
        'Build a workflow that reads leads from my table, researches each prospect and their company on the web, writes a personalized cold email tailored to their role and pain points, and sends it via Gmail. Schedule it to run daily to process new leads automatically.',
    iconId: 'brand/gmail-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'google-email',
  ),
  SuggestionTemplate(
    id: 'gmail-2',
    blockType: 'gmail',
    label: 'Gmail knowledge search',
    prompt:
        'Create a knowledge base connected to my Gmail so all my emails are automatically synced, chunked, and searchable. Then build an agent I can ask things like "what did Sarah say about the pricing proposal?" or "find the contract John sent last month" and get instant answers with the original email cited.',
    iconId: 'brand/gmail-icon',
    modules: <String>['knowledge-base', 'agent'],
    providerId: 'google-email',
  ),
  SuggestionTemplate(
    id: 'gmail-3',
    blockType: 'gmail',
    label: 'Gmail triage assistant',
    prompt:
        'Build a workflow that scans my Gmail inbox every hour, categorizes emails by urgency and type (action needed, FYI, follow-up), drafts replies for routine messages, and sends me a prioritized summary in Slack so I only open what matters. Schedule it to run hourly.',
    iconId: 'brand/gmail-icon',
    modules: <String>['agent', 'scheduled', 'workflows'],
    providerId: 'google-email',
  ),
  SuggestionTemplate(
    id: 'gmail-4',
    blockType: 'gmail',
    label: 'Gmail invoice processor',
    prompt:
        'Build a workflow that processes invoice PDFs from Gmail, extracts vendor name, amount, due date, and line items, then logs everything to a tracking table and sends a Slack alert for invoices due within 7 days.',
    iconId: 'emcn/clipboard-list',
    modules: <String>['files', 'tables', 'agent', 'workflows'],
    providerId: 'google-email',
  ),
  SuggestionTemplate(
    id: 'gmail-5',
    blockType: 'gmail',
    label: 'Gmail to CRM activity logger',
    prompt:
        'Build a workflow that reads new Gmail threads with customers, extracts the contact, deal context, and key points discussed, and logs a timestamped activity to the matching HubSpot contact or deal so every conversation stays attached to the record.',
    iconId: 'brand/gmail-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'google-email',
  ),
  SuggestionTemplate(
    id: 'gmail-6',
    blockType: 'gmail',
    label: 'Gmail attachment vault',
    prompt:
        'Create a workflow that watches Gmail for new emails with attachments, saves each attachment into a categorized folder in Google Drive based on sender and subject, and logs a row to a tracking table with the file link and source email.',
    iconId: 'brand/gmail-icon',
    modules: <String>['tables', 'files', 'agent', 'workflows'],
    providerId: 'google-email',
  ),
  SuggestionTemplate(
    id: 'gmail-7',
    blockType: 'gmail',
    label: 'Gmail to Notion email capture',
    prompt:
        'Build a workflow that monitors Gmail for incoming emails, extracts structured data from each one, and stores it as a Notion database entry — useful for lead capture, support tickets, and meeting scheduling.',
    iconId: 'brand/gmail-icon',
    modules: <String>['agent', 'workflows'],
    featured: true,
    providerId: 'google-email',
  ),
  SuggestionTemplate(
    id: 'gong-0',
    blockType: 'gong',
    label: 'Gong sales call analyzer',
    prompt:
        'Build a workflow that pulls call transcripts from Gong after each sales call, identifies key objections raised, action items promised, and competitor mentions, updates the deal record in my CRM, and posts a call summary with next steps to the Slack deal channel.',
    iconId: 'brand/gong-icon',
    modules: <String>['agent', 'tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'gong-1',
    blockType: 'gong',
    label: 'Gong objection tracker',
    prompt:
        'Build a scheduled weekly workflow that scans Gong sales calls for recurring objections, scores frequency and stage, and writes a competitive-intel digest to Slack.',
    iconId: 'brand/gong-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'gong-2',
    blockType: 'gong',
    label: 'Gong deal-risk surfacer',
    prompt:
        'Create a workflow that monitors Gong conversation intelligence signals, identifies deals at risk based on talk patterns, and posts a Slack alert to the AE and manager.',
    iconId: 'brand/gong-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'gong-3',
    blockType: 'gong',
    label: 'Gong coaching dashboard',
    prompt:
        'Build a scheduled weekly workflow that pulls Gong per-rep metrics — talk ratio, longest monologue, question rate — and writes a coaching table for managers.',
    iconId: 'brand/gong-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'gong-4',
    blockType: 'gong',
    label: 'Gong customer-quote miner',
    prompt:
        'Create a workflow that processes Gong customer interview calls, extracts notable quotes and themes, and writes them to a marketing research table.',
    iconId: 'brand/gong-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'gong-5',
    blockType: 'gong',
    label: 'Gong CRM auto-updater',
    prompt:
        'Build a workflow that runs after a Gong sales call, summarizes objections and next steps, and updates the linked Salesforce or HubSpot opportunity with notes.',
    iconId: 'brand/gong-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'gong-6',
    blockType: 'gong',
    label: 'Gong competitor-mention tracker',
    prompt:
        'Create a workflow that scans Gong calls for competitor mentions, captures context and outcome, and writes the competitive intel to a tracking table.',
    iconId: 'brand/gong-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_ads-0',
    blockType: 'google_ads',
    label: 'Google Ads spend pacing',
    prompt:
        'Build a scheduled daily workflow that pulls Google Ads campaign spend, compares against monthly budget, and posts a Slack alert when any campaign is pacing more than 15% over.',
    iconId: 'brand/google-ads-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'google-ads',
  ),
  SuggestionTemplate(
    id: 'google_ads-1',
    blockType: 'google_ads',
    label: 'Google Ads keyword performance report',
    prompt:
        'Create a scheduled weekly workflow that pulls Google Ads keyword performance, flags keywords with rising CPCs or dropping CTRs, and writes a recommendation list to a file.',
    iconId: 'brand/google-ads-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
    providerId: 'google-ads',
  ),
  SuggestionTemplate(
    id: 'google_ads-2',
    blockType: 'google_ads',
    label: 'Google Ads negative-keyword finder',
    prompt:
        'Build a scheduled workflow that scans Google Ads search-term performance weekly, identifies irrelevant terms wasting spend, and writes a recommended negative-keyword list to a file for the team to review.',
    iconId: 'brand/google-ads-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
    providerId: 'google-ads',
  ),
  SuggestionTemplate(
    id: 'google_ads-3',
    blockType: 'google_ads',
    label: 'Google Ads + Stripe ROAS tracker',
    prompt:
        'Create a scheduled workflow that joins Google Ads spend with Stripe revenue only where an explicit campaign ID or UTM mapping was captured, reports unmatched revenue separately, calculates attributed ROAS with that limitation, and posts the per-channel breakdown to Slack each morning.',
    iconId: 'brand/google-ads-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'google-ads',
  ),
  SuggestionTemplate(
    id: 'google_ads-4',
    blockType: 'google_ads',
    label: 'Google Ads + PageSpeed landing audit',
    prompt:
        'Create a scheduled workflow that for active Google Ads campaigns runs Google PageSpeed on the landing pages weekly, flags slow LPs, and pings the marketing team.',
    iconId: 'brand/google-ads-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'google-ads',
  ),
  SuggestionTemplate(
    id: 'google_ads-5',
    blockType: 'google_ads',
    label: 'Google Ads + Profound brand comparison',
    prompt:
        'Build a scheduled workflow that joins Google Ads spend per campaign with Profound AI brand-visibility scores, writes a comparison table without claiming causal attribution, and posts findings to Slack.',
    iconId: 'brand/google-ads-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'google-ads',
  ),
  SuggestionTemplate(
    id: 'google_ads-6',
    blockType: 'google_ads',
    label: 'Google Ads creative auditor',
    prompt:
        'Create a scheduled workflow that pulls Google Ads creatives, scores ad copy quality with an agent, and writes a per-campaign creative review file.',
    iconId: 'brand/google-ads-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
    providerId: 'google-ads',
  ),
  SuggestionTemplate(
    id: 'google_appsheet-0',
    blockType: 'google_appsheet',
    label: 'AppSheet order intake',
    prompt:
        'Build a workflow triggered by a form submission that adds a new row to an AppSheet Orders table, then posts a confirmation message to Slack with the order details.',
    iconId: 'brand/google-appsheet-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_appsheet-1',
    blockType: 'google_appsheet',
    label: 'AppSheet daily status digest',
    prompt:
        'Create a scheduled workflow that runs daily, finds all AppSheet rows where Status is "Open", summarizes them with an agent, and emails the summary to the operations team.',
    iconId: 'brand/google-appsheet-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_appsheet-2',
    blockType: 'google_appsheet',
    label: 'AppSheet inventory sync',
    prompt:
        'Build a workflow that reads updated rows from an AppSheet Inventory table, transforms the quantities with an agent, and writes the reconciled totals into a Google Sheet.',
    iconId: 'brand/google-appsheet-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_appsheet-3',
    blockType: 'google_appsheet',
    label: 'AppSheet ticket escalation',
    prompt:
        'Build a workflow that finds AppSheet rows where Priority is "High" and Status is not "Resolved", and edits each row to add an Escalated flag, then creates a Linear issue for each one.',
    iconId: 'brand/google-appsheet-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_appsheet-4',
    blockType: 'google_appsheet',
    label: 'AppSheet cleanup job',
    prompt:
        'Create a scheduled workflow that finds AppSheet rows older than 90 days with Status "Archived" and deletes them, then logs a summary of how many rows were removed to a table.',
    iconId: 'brand/google-appsheet-icon',
    modules: <String>['scheduled', 'tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_appsheet-5',
    blockType: 'google_appsheet',
    label: 'AppSheet lead router',
    prompt:
        'Build a workflow that finds new AppSheet rows in a Leads table, uses an agent to classify each lead by region, and edits the row to assign the correct sales rep.',
    iconId: 'brand/google-appsheet-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_appsheet-6',
    blockType: 'google_appsheet',
    label: 'AppSheet field service report',
    prompt:
        'Build a workflow that finds all AppSheet rows completed today in a Work Orders table, generates a summary report with an agent, and saves it as a file for the team.',
    iconId: 'brand/google-appsheet-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_bigquery-0',
    blockType: 'google_bigquery',
    label: 'BigQuery scheduled report runner',
    prompt:
        'Build a scheduled workflow that runs a saved BigQuery query daily, writes the result rows to a Sim table, and posts a Slack summary of the top movers.',
    iconId: 'brand/google-big-query-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'google-bigquery',
  ),
  SuggestionTemplate(
    id: 'google_bigquery-1',
    blockType: 'google_bigquery',
    label: 'BigQuery customer 360 builder',
    prompt:
        'Create a scheduled workflow that joins BigQuery sources — Stripe, product events, support tickets — into a single per-customer profile table refreshed daily.',
    iconId: 'brand/google-big-query-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'google-bigquery',
  ),
  SuggestionTemplate(
    id: 'google_bigquery-2',
    blockType: 'google_bigquery',
    label: 'BigQuery cost-tracking alerts',
    prompt:
        'Build a scheduled daily workflow that pulls BigQuery slot and storage usage, projects month-end spend, and posts a Slack alert when projection exceeds budget.',
    iconId: 'brand/google-big-query-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'google-bigquery',
  ),
  SuggestionTemplate(
    id: 'google_bigquery-3',
    blockType: 'google_bigquery',
    label: 'BigQuery anomaly notifier',
    prompt:
        'Create a workflow that runs BigQuery anomaly-detection queries on key metrics hourly, writes any anomalies to a tracking table, and pages the on-call data team on severe deltas.',
    iconId: 'brand/google-big-query-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'google-bigquery',
  ),
  SuggestionTemplate(
    id: 'google_bigquery-4',
    blockType: 'google_bigquery',
    label: 'BigQuery + Sheets exec dashboard',
    prompt:
        'Build a scheduled workflow that pulls a BigQuery executive dashboard query weekly, writes the result into a chosen Google Sheet, and notifies leadership the new snapshot is ready.',
    iconId: 'brand/google-big-query-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'google-bigquery',
  ),
  SuggestionTemplate(
    id: 'google_bigquery-5',
    blockType: 'google_bigquery',
    label: 'BigQuery schema drift detector',
    prompt:
        'Create a scheduled workflow that snapshots BigQuery dataset schemas, diffs against the prior snapshot, and opens a Linear ticket on unexpected schema changes.',
    iconId: 'brand/google-big-query-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'google-bigquery',
  ),
  SuggestionTemplate(
    id: 'google_bigquery-6',
    blockType: 'google_bigquery',
    label: 'BigQuery NL analytics agent',
    prompt:
        'Build a Slack agent that lists BigQuery datasets and tables to understand the schema, translates a teammate\'s natural-language question into a safe BigQuery SQL query, runs it, and replies with the result table plus the query used.',
    iconId: 'brand/google-big-query-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'google-bigquery',
  ),
  SuggestionTemplate(
    id: 'google_books-0',
    blockType: 'google_books',
    label: 'Google Books citation finder',
    prompt:
        'Build a workflow that takes a topic, queries Google Books for relevant titles and quotes, and writes a citations bibliography file for research papers.',
    iconId: 'brand/google-books-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_books-1',
    blockType: 'google_books',
    label: 'Google Books reading list builder',
    prompt:
        'Create a workflow that takes a topic, finds top-rated Google Books titles, writes a curated reading-list file with summaries, and emails it to the user.',
    iconId: 'brand/google-books-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_books-2',
    blockType: 'google_books',
    label: 'Google Books research enricher',
    prompt:
        'Build a workflow that for each topic in a research table queries Google Books for foundational works, captures the key passages, and writes them to a knowledge base.',
    iconId: 'brand/google-books-icon',
    modules: <String>['knowledge-base', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_books-3',
    blockType: 'google_books',
    label: 'Google Books quote miner',
    prompt:
        'Create a workflow that searches Google Books for quotes on a topic, scores by relevance, and writes the top quotes to a marketing content table.',
    iconId: 'brand/google-books-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_books-4',
    blockType: 'google_books',
    label: 'Google Books bibliographic agent',
    prompt:
        'Build a research agent that uses Google Books as one of its tools to find canonical sources and properly cite them in answers with ISBN and page references.',
    iconId: 'brand/google-books-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_books-5',
    blockType: 'google_books',
    label: 'Google Books due-diligence helper',
    prompt:
        'Create a workflow that for a tracked person or company searches Google Books for prior publications and citations, and writes the findings to a CRM intel record.',
    iconId: 'brand/google-books-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_books-6',
    blockType: 'google_books',
    label: 'Google Books topic explorer',
    prompt:
        'Build an agent that explores a topic across Google Books, identifies adjacent themes from book metadata, and writes a topic map to a research file.',
    iconId: 'brand/google-books-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_calendar-0',
    blockType: 'google_calendar',
    label: 'Calendar meeting prep agent',
    prompt:
        'Create an agent that checks my Google Calendar each morning, researches every attendee and topic on the web, and prepares a brief for each meeting so I walk in fully prepared. Schedule it to run every weekday morning.',
    iconId: 'brand/google-calendar-icon',
    modules: <String>['agent', 'scheduled', 'workflows'],
    featured: true,
    popular: true,
    providerId: 'google-calendar',
  ),
  SuggestionTemplate(
    id: 'google_calendar-1',
    blockType: 'google_calendar',
    label: 'Calendar SMS appointment reminders',
    prompt:
        'Create a scheduled workflow that checks Google Calendar each morning for appointments in the next 24 hours, and sends an SMS reminder to each attendee via Twilio with the meeting time, location, and any prep notes.',
    iconId: 'brand/google-calendar-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'google-calendar',
  ),
  SuggestionTemplate(
    id: 'google_calendar-2',
    blockType: 'google_calendar',
    label: 'Booking-to-calendar scheduler',
    prompt:
        'Build a workflow that on a new Calendly booking creates the matching Google Calendar event, invites the attendees, attaches the meeting agenda, and writes the event link back so both systems stay in sync.',
    iconId: 'brand/google-calendar-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'google-calendar',
  ),
  SuggestionTemplate(
    id: 'google_calendar-3',
    blockType: 'google_calendar',
    label: 'Calendar daily agenda digest',
    prompt:
        'Create a scheduled weekday workflow that lists my Google Calendar events for the day, summarizes them with attendee context and prep notes, and posts a clean morning agenda to Slack.',
    iconId: 'brand/google-calendar-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'google-calendar',
  ),
  SuggestionTemplate(
    id: 'google_calendar-4',
    blockType: 'google_calendar',
    label: 'Calendar interview scheduler',
    prompt:
        'Build a workflow that when a candidate reaches the interview stage finds open slots across the panel\'s Google Calendars, creates the interview event with the video link, invites everyone, and emails the candidate the confirmation.',
    iconId: 'brand/google-calendar-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'google-calendar',
  ),
  SuggestionTemplate(
    id: 'google_calendar-5',
    blockType: 'google_calendar',
    label: 'Calendar meeting-load weekly report',
    prompt:
        'Create a scheduled weekly workflow that lists Google Calendar events for the team, computes total meeting hours and recurring-meeting load per person, writes the breakdown to a table, and flags anyone over the focus-time threshold.',
    iconId: 'brand/google-calendar-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'google-calendar',
  ),
  SuggestionTemplate(
    id: 'google_calendar-6',
    blockType: 'google_calendar',
    label: 'Calendar event note-taker prep',
    prompt:
        'Build a workflow that scans upcoming Google Calendar events for external meetings, researches each company and attendee, drafts talking points, and updates the event description so the notes travel with the invite.',
    iconId: 'brand/google-calendar-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'google-calendar',
  ),
  SuggestionTemplate(
    id: 'google_contacts-0',
    blockType: 'google_contacts',
    label: 'Google Contacts CRM sync',
    prompt:
        'Build a scheduled workflow that mirrors Google Contacts into HubSpot, adding new contacts and updating fields, and writing a sync log for hygiene tracking.',
    iconId: 'brand/google-contacts-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'google-contacts',
  ),
  SuggestionTemplate(
    id: 'google_contacts-1',
    blockType: 'google_contacts',
    label: 'Google Contacts duplicate cleaner',
    prompt:
        'Create a scheduled workflow that scans Google Contacts for duplicates, merges them deterministically, and writes a cleanup report for review.',
    iconId: 'brand/google-contacts-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'google-contacts',
  ),
  SuggestionTemplate(
    id: 'google_contacts-2',
    blockType: 'google_contacts',
    label: 'Google Contacts enricher',
    prompt:
        'Build a scheduled workflow that scans Google Contacts for entries missing company or title, enriches each via Apollo, and writes the enriched contact back to Google Contacts.',
    iconId: 'brand/google-contacts-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'google-contacts',
  ),
  SuggestionTemplate(
    id: 'google_contacts-3',
    blockType: 'google_contacts',
    label: 'Google Contacts + Calendar grouper',
    prompt:
        'Create a workflow that groups Google Contacts into labels based on meeting frequency in Google Calendar, so frequent collaborators are easy to find when composing emails.',
    iconId: 'brand/google-contacts-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'google-contacts',
  ),
  SuggestionTemplate(
    id: 'google_contacts-4',
    blockType: 'google_contacts',
    label: 'Google Contacts birthday reminder',
    prompt:
        'Build a scheduled workflow that runs daily, surfaces upcoming birthdays from Google Contacts, and emails the user a reminder with personalized message suggestions.',
    iconId: 'brand/google-contacts-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'google-contacts',
  ),
  SuggestionTemplate(
    id: 'google_contacts-5',
    blockType: 'google_contacts',
    label: 'Google Contacts deal-mapper',
    prompt:
        'Create a workflow that maps Google Contacts to active Salesforce opportunities by email domain, tagging contacts as deal-relevant for fast follow-ups.',
    iconId: 'brand/google-contacts-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'google-contacts',
  ),
  SuggestionTemplate(
    id: 'google_contacts-6',
    blockType: 'google_contacts',
    label: 'Google Contacts new-hire onboarder',
    prompt:
        'Build a workflow that on a new hire in Workday adds the new employee to relevant Google Contacts groups based on department and team.',
    iconId: 'brand/google-contacts-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'google-contacts',
  ),
  SuggestionTemplate(
    id: 'google_docs-0',
    blockType: 'google_docs',
    label: 'Google Docs review request',
    prompt:
        'Build a workflow that reads a Google Doc when its title is marked ready for review, summarizes the key points with an agent, and posts a review request with the doc link to the named reviewers in Slack.',
    iconId: 'brand/google-docs-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'google-docs',
  ),
  SuggestionTemplate(
    id: 'google_docs-1',
    blockType: 'google_docs',
    label: 'Google Docs change digester',
    prompt:
        'Create a scheduled weekly workflow that reads each tracked Google Doc, compares its content against the snapshot stored in a table, summarizes what changed with an agent, and posts a digest to the team in Slack.',
    iconId: 'brand/google-docs-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'google-docs',
  ),
  SuggestionTemplate(
    id: 'google_docs-2',
    blockType: 'google_docs',
    label: 'Google Docs translation copy',
    prompt:
        'Build a workflow that takes a Google Docs document and creates translated copies into target languages with Google Translate, links them in the source, and notifies the localization team.',
    iconId: 'brand/google-docs-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'google-docs',
  ),
  SuggestionTemplate(
    id: 'google_docs-3',
    blockType: 'google_docs',
    label: 'Meeting notes to Google Docs',
    prompt:
        'Create a workflow that after a meeting pulls the transcript, summarizes decisions, action items, and owners with an agent, and creates a formatted Google Docs document in the shared team folder with a link posted to Slack.',
    iconId: 'brand/google-docs-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'google-docs',
  ),
  SuggestionTemplate(
    id: 'google_docs-4',
    blockType: 'google_docs',
    label: 'Google Docs proposal generator',
    prompt:
        'Build a workflow that on a closed-won deal reads the account details, creates a Google Docs document from the proposal template, fills in customer name, scope, and pricing, and shares the draft with the account owner for review.',
    iconId: 'brand/google-docs-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'google-docs',
  ),
  SuggestionTemplate(
    id: 'google_docs-5',
    blockType: 'google_docs',
    label: 'Google Docs weekly report',
    prompt:
        'Create a scheduled weekly workflow that reads metrics from my tables, writes a narrative status report with an agent, and appends the new section to a running Google Docs document so leadership has one living record.',
    iconId: 'brand/google-docs-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'google-docs',
  ),
  SuggestionTemplate(
    id: 'google_docs-6',
    blockType: 'google_docs',
    label: 'Google Docs knowledge sync',
    prompt:
        'Build a workflow that reads a set of Google Docs in a folder, extracts their content, and upserts it into a knowledge base so the team can ask questions and get answers grounded in the latest docs.',
    iconId: 'brand/google-docs-icon',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
    providerId: 'google-docs',
  ),
  SuggestionTemplate(
    id: 'google_drive-0',
    blockType: 'google_drive',
    label: 'Google Drive personal notes assistant',
    prompt:
        'Create a knowledge base and connect it to my Google Drive, Notion, or Obsidian so all my notes, docs, and articles are automatically synced and embedded. Then build an agent that I can ask anything — it should answer with citations and deploy as a chat endpoint.',
    iconId: 'emcn/book-open',
    modules: <String>['knowledge-base', 'agent'],
    providerId: 'google-drive',
  ),
  SuggestionTemplate(
    id: 'google_drive-1',
    blockType: 'google_drive',
    label: 'Google Drive knowledge search',
    prompt:
        'Create a knowledge base connected to my Google Drive so all documents, spreadsheets, and presentations are automatically synced and searchable. Then build an agent I can ask things like "find the board deck from last quarter" or "what were the KPIs in the marketing plan?" and get answers with doc links.',
    iconId: 'brand/google-drive-icon',
    modules: <String>['knowledge-base', 'agent'],
    providerId: 'google-drive',
  ),
  SuggestionTemplate(
    id: 'google_drive-2',
    blockType: 'google_drive',
    label: 'Google Drive contract intake',
    prompt:
        'Create a workflow that watches a Google Drive intake folder for new contract PDFs, extracts clauses with Reducto, writes structured terms to a table, and pings legal in Slack.',
    iconId: 'brand/google-drive-icon',
    modules: <String>['files', 'tables', 'agent', 'workflows'],
    providerId: 'google-drive',
  ),
  SuggestionTemplate(
    id: 'google_drive-3',
    blockType: 'google_drive',
    label: 'Google Drive new-hire kit deployer',
    prompt:
        'Build a workflow triggered by a new hire in Greenhouse that copies the standard Google Drive onboarding folder, shares it with the new hire, and writes the link into the onboarding tracker.',
    iconId: 'brand/google-drive-icon',
    modules: <String>['files', 'agent', 'workflows'],
    providerId: 'google-drive',
  ),
  SuggestionTemplate(
    id: 'google_drive-4',
    blockType: 'google_drive',
    label: 'Google Drive retention enforcer',
    prompt:
        'Create a scheduled monthly workflow that finds Google Drive files past the retention horizon, requires owner approval over Slack, and archives or deletes per the policy.',
    iconId: 'brand/google-drive-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'google-drive',
  ),
  SuggestionTemplate(
    id: 'google_drive-5',
    blockType: 'google_drive',
    label: 'Drive intake auto-filer',
    prompt:
        'Build a workflow that watches a Google Drive intake folder for new uploads, reads each file\'s content to classify it by type and customer, creates the right destination folder, and moves the file there with a renamed, consistent filename.',
    iconId: 'brand/google-drive-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'google-drive',
  ),
  SuggestionTemplate(
    id: 'google_drive-6',
    blockType: 'google_drive',
    label: 'Drive document Q&A assistant',
    prompt:
        'Create a knowledge base synced from a Google Drive folder, then build an agent that searches the synced documents to answer team questions and replies with the answer plus a link to the source file in Drive.',
    iconId: 'emcn/book-open',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
    providerId: 'google-drive',
  ),
  SuggestionTemplate(
    id: 'google_forms-0',
    blockType: 'google_forms',
    label: 'Google Forms to CRM',
    prompt:
        'Build a workflow that watches Google Forms responses, enriches each submitter with company data, and pushes qualified leads into HubSpot with the right owner and source.',
    iconId: 'brand/google-forms-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'google-forms',
  ),
  SuggestionTemplate(
    id: 'google_forms-1',
    blockType: 'google_forms',
    label: 'Google Forms support intake',
    prompt:
        'Create a workflow that turns Google Forms support submissions into Zendesk tickets, prioritizes them with an agent, and posts the new ticket to the support Slack channel.',
    iconId: 'brand/google-forms-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'google-forms',
  ),
  SuggestionTemplate(
    id: 'google_forms-2',
    blockType: 'google_forms',
    label: 'Google Forms event RSVP tracker',
    prompt:
        'Build a workflow that captures Google Forms event RSVPs into a table, sends confirmation emails, and provides a daily attendee dashboard to the organizer.',
    iconId: 'brand/google-forms-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'google-forms',
  ),
  SuggestionTemplate(
    id: 'google_forms-3',
    blockType: 'google_forms',
    label: 'Google Forms survey analyzer',
    prompt:
        'Create a workflow that processes Google Forms survey responses, classifies sentiment and themes with an agent, and writes a weekly insight digest to Slack.',
    iconId: 'brand/google-forms-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'google-forms',
  ),
  SuggestionTemplate(
    id: 'google_forms-4',
    blockType: 'google_forms',
    label: 'Google Forms approvals router',
    prompt:
        'Build a workflow that turns Google Forms approval requests into Slack messages with quick-action buttons, captures the decision, and emails the requester the outcome.',
    iconId: 'brand/google-forms-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'google-forms',
  ),
  SuggestionTemplate(
    id: 'google_forms-5',
    blockType: 'google_forms',
    label: 'Google Forms PTO collector',
    prompt:
        'Create a workflow that processes PTO requests from Google Forms, captures manager approval over Slack, and updates the HR table with approved time off.',
    iconId: 'brand/google-forms-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'google-forms',
  ),
  SuggestionTemplate(
    id: 'google_forms-6',
    blockType: 'google_forms',
    label: 'Google Forms quiz grader',
    prompt:
        'Build a workflow that captures Google Forms quiz responses, scores each automatically with an agent, writes scores to a tables-based gradebook, and emails the student.',
    iconId: 'brand/google-forms-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'google-forms',
  ),
  SuggestionTemplate(
    id: 'google_groups-0',
    blockType: 'google_groups',
    label: 'Google Groups onboarding sync',
    prompt:
        'Create a workflow that watches Rippling or Greenhouse for new hires, adds them to the right Google Groups based on team and department, and emails the new hire a list of the groups joined.',
    iconId: 'brand/google-groups-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'google-groups',
  ),
  SuggestionTemplate(
    id: 'google_groups-1',
    blockType: 'google_groups',
    label: 'Google Groups quarterly access review',
    prompt:
        'Build a scheduled workflow that runs each quarter, lists every Google Group with members and owners, writes the report to a table for compliance review, and pings owners to confirm membership in Slack.',
    iconId: 'brand/google-groups-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'google-groups',
  ),
  SuggestionTemplate(
    id: 'google_groups-2',
    blockType: 'google_groups',
    label: 'Google Groups departure cleanup',
    prompt:
        'Create a workflow that watches Workday or Rippling for terminations and removes the departing user from every Google Group they belonged to, writing the change to a security audit log.',
    iconId: 'brand/google-groups-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'google-groups',
  ),
  SuggestionTemplate(
    id: 'google_groups-3',
    blockType: 'google_groups',
    label: 'Google Groups self-serve requester',
    prompt:
        'Build a workflow that accepts a Google Group access request via a form, gets manager approval over Slack, adds the user to the group, and notifies the requester when access is granted.',
    iconId: 'brand/google-groups-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'google-groups',
  ),
  SuggestionTemplate(
    id: 'google_groups-4',
    blockType: 'google_groups',
    label: 'Google Groups distribution-list audit',
    prompt:
        'Create a scheduled workflow that scans Google Groups marked as distribution lists, flags external members against an allowlist, and posts a Slack report to the security team.',
    iconId: 'brand/google-groups-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'google-groups',
  ),
  SuggestionTemplate(
    id: 'google_groups-5',
    blockType: 'google_groups',
    label: 'Google Groups empty-group cleanup',
    prompt:
        'Build a scheduled workflow that lists Google Groups with no members, opens a confirmation thread with the owner in Slack, and deletes the group once approved.',
    iconId: 'brand/google-groups-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'google-groups',
  ),
  SuggestionTemplate(
    id: 'google_groups-6',
    blockType: 'google_groups',
    label: 'Google Groups settings hardening',
    prompt:
        'Create a scheduled workflow that reads the settings for every Google Group, flags groups that allow external posting or open membership against policy, and posts the findings to the security team in Slack.',
    iconId: 'brand/google-groups-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'google-groups',
  ),
  SuggestionTemplate(
    id: 'google_maps-0',
    blockType: 'google_maps',
    label: 'Google Maps competitor location finder',
    prompt:
        'Build a workflow that uses Google Maps to find competitor locations in a target city, writes coordinates and details to a table, and emails the sales team a route map.',
    iconId: 'brand/google-maps-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_maps-1',
    blockType: 'google_maps',
    label: 'Google Maps territory builder',
    prompt:
        'Create a workflow that takes a list of CRM accounts, geocodes them via Google Maps, clusters into territories, and writes the assignment to a tables-based territory plan.',
    iconId: 'brand/google-maps-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_maps-2',
    blockType: 'google_maps',
    label: 'Google Maps event-attendee proximity',
    prompt:
        'Build a workflow that for a Luma event sorts registrants by proximity to the venue via Google Maps, writes the list, and offers a quick-action transport option.',
    iconId: 'brand/google-maps-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_maps-3',
    blockType: 'google_maps',
    label: 'Google Maps logistics planner',
    prompt:
        'Create a workflow that takes a delivery list, optimizes the route via Google Maps directions, and writes a per-driver itinerary to a tables-based dispatcher view.',
    iconId: 'brand/google-maps-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_maps-4',
    blockType: 'google_maps',
    label: 'Google Maps store-locator updater',
    prompt:
        'Build a scheduled workflow that audits store locations on the website against Google Maps Places data, flags out-of-date hours or addresses, and pings the team to correct.',
    iconId: 'brand/google-maps-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_maps-5',
    blockType: 'google_maps',
    label: 'Google Maps review tracker',
    prompt:
        'Create a scheduled workflow that watches Google Maps reviews of brand locations daily, classifies sentiment, and pings the right manager in Slack on new negative reviews.',
    iconId: 'brand/google-maps-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_maps-6',
    blockType: 'google_maps',
    label: 'Google Maps lead-by-region exporter',
    prompt:
        'Build a workflow that uses Google Maps to find businesses matching an ICP in a region, enriches via Hunter, and writes the prospect list to HubSpot.',
    iconId: 'brand/google-maps-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_meet-0',
    blockType: 'google_meet',
    label: 'Google Meet conference recap to Drive',
    prompt:
        'Build a workflow that pulls the conference record and participant list for a finished Google Meet, generates a structured attendance and follow-up recap with an agent, and saves the document to a per-team folder in Google Drive.',
    iconId: 'brand/google-meet-icon',
    modules: <String>['agent', 'files', 'workflows'],
    providerId: 'google-meet',
  ),
  SuggestionTemplate(
    id: 'google_meet-1',
    blockType: 'google_meet',
    label: 'Google Meet daily meeting links',
    prompt:
        'Create a scheduled workflow that reads the day\'s meetings from a table each morning, creates a Google Meet space for each one, and emails attendees the agenda and join link via Gmail.',
    iconId: 'brand/google-meet-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'google-meet',
  ),
  SuggestionTemplate(
    id: 'google_meet-2',
    blockType: 'google_meet',
    label: 'Google Meet conference record archiver',
    prompt:
        'Build a scheduled workflow that lists Google Meet conference records, captures attendance and duration per meeting, and writes the history to a source-of-truth meetings table for reporting.',
    iconId: 'brand/google-meet-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'google-meet',
  ),
  SuggestionTemplate(
    id: 'google_meet-3',
    blockType: 'google_meet',
    label: 'Google Meet auto-invite from CRM',
    prompt:
        'Create a workflow that watches Salesforce for new meetings logged on opportunities, creates a matching Google Meet event, invites the right attendees, and writes the meeting link back to the opportunity.',
    iconId: 'brand/google-meet-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'google-meet',
  ),
  SuggestionTemplate(
    id: 'google_meet-4',
    blockType: 'google_meet',
    label: 'Google Meet daily standup link',
    prompt:
        'Build a scheduled workflow that posts the day’s Google Meet standup link to the team Slack channel five minutes before standup, with the rolling agenda from the standup table.',
    iconId: 'brand/google-meet-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'google-meet',
  ),
  SuggestionTemplate(
    id: 'google_meet-5',
    blockType: 'google_meet',
    label: 'Google Meet customer interview logger',
    prompt:
        'Create a workflow that takes a customer-interview note or transcript, pulls the matching Google Meet conference record and participants for context, extracts themes, quotes, and feature requests with an agent, and writes structured rows to a research table.',
    iconId: 'brand/google-meet-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'google-meet',
  ),
  SuggestionTemplate(
    id: 'google_meet-6',
    blockType: 'google_meet',
    label: 'Google Meet retro publisher',
    prompt:
        'Build a workflow that runs after a sprint-retro Google Meet, summarizes what went well, what to improve, and action items, and posts the retro to a Notion page tagged with the sprint number.',
    iconId: 'brand/google-meet-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'google-meet',
  ),
  SuggestionTemplate(
    id: 'google_pagespeed-0',
    blockType: 'google_pagespeed',
    label: 'PageSpeed monitor for top pages',
    prompt:
        'Create a scheduled workflow that runs Google PageSpeed Insights weekly against my top landing pages, writes mobile and desktop scores to a tables-based history, and flags regressions in Slack.',
    iconId: 'brand/google-pagespeed-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_pagespeed-1',
    blockType: 'google_pagespeed',
    label: 'PageSpeed sitemap audit',
    prompt:
        'Build a workflow that takes a sitemap URL, runs Google PageSpeed Insights against every page in batches, summarizes Core Web Vitals across the site, and saves the report as a file.',
    iconId: 'brand/google-pagespeed-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_pagespeed-2',
    blockType: 'google_pagespeed',
    label: 'PageSpeed pre-deploy gate',
    prompt:
        'Build a workflow triggered by a Vercel preview deployment that runs Google PageSpeed Insights against the preview URL, posts the scores as a GitHub PR comment, and fails the check if scores drop below threshold.',
    iconId: 'brand/google-pagespeed-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_pagespeed-3',
    blockType: 'google_pagespeed',
    label: 'PageSpeed CWV regression watcher',
    prompt:
        'Build a scheduled workflow that runs Google PageSpeed Insights daily for the top pages, captures Core Web Vitals, and pages on-call when LCP or CLS regress beyond threshold.',
    iconId: 'brand/google-pagespeed-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_pagespeed-4',
    blockType: 'google_pagespeed',
    label: 'PageSpeed accessibility tracker',
    prompt:
        'Build a scheduled weekly workflow that runs Google PageSpeed Insights with the accessibility audit, writes per-page scores to a tracking table, and opens Linear tickets on regressions.',
    iconId: 'brand/google-pagespeed-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_pagespeed-5',
    blockType: 'google_pagespeed',
    label: 'PageSpeed CWV release gate',
    prompt:
        'Create a workflow triggered after a marketing-site deploy that runs Google PageSpeed Insights on the key landing pages for both mobile and desktop, compares Core Web Vitals against the prior baseline, and posts a pass/fail summary to Slack with the specific metrics that regressed.',
    iconId: 'brand/google-pagespeed-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_pagespeed-6',
    blockType: 'google_pagespeed',
    label: 'PageSpeed competitor benchmark',
    prompt:
        'Build a workflow that runs Google PageSpeed Insights against my homepage and a list of competitor URLs on mobile, compares the performance scores and Core Web Vitals side by side, and writes the ranked benchmark to a sheet.',
    iconId: 'brand/google-pagespeed-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_search-0',
    blockType: 'google_search',
    label: 'Daily news digest',
    prompt:
        'Create a scheduled daily workflow that runs Google searches for the topics and competitors I care about, picks the most relevant fresh results, summarizes each in a sentence, and emails me a curated digest every morning.',
    iconId: 'brand/google-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_search-1',
    blockType: 'google_search',
    label: 'Lead company researcher',
    prompt:
        'Build a workflow that watches my leads table for new rows, runs Google searches for each company\'s recent news, funding, and leadership, summarizes the findings with an agent, and writes a research brief back to the row.',
    iconId: 'brand/google-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_search-2',
    blockType: 'google_search',
    label: 'SERP rank tracker',
    prompt:
        'Create a scheduled weekly workflow that runs Google searches for my target keywords, records where my domain appears in the results, logs positions to a tables-based scorecard, and posts a Slack summary of gainers and losers.',
    iconId: 'brand/google-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_search-3',
    blockType: 'google_search',
    label: 'Brand mention monitor',
    prompt:
        'Build a scheduled workflow that searches Google for new mentions of my brand and key executives, filters out noise with an agent, and posts notable mentions with links to a Slack channel for the comms team.',
    iconId: 'brand/google-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_search-4',
    blockType: 'google_search',
    label: 'Research-backed answer agent',
    prompt:
        'Create an agent that takes any question, runs targeted Google searches to gather current sources, synthesizes a concise answer with citations, and returns it so the team gets sourced answers instead of guesses.',
    iconId: 'brand/google-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_search-5',
    blockType: 'google_search',
    label: 'Content gap explorer',
    prompt:
        'Build a workflow that runs Google searches for a seed topic and its related queries, extracts the recurring subtopics and questions competitors rank for, and writes a prioritized content brief to a table.',
    iconId: 'brand/google-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_search-6',
    blockType: 'google_search',
    label: 'Support answer finder',
    prompt:
        'Create a workflow that on a new support ticket runs Google searches scoped to our docs and trusted sources, finds the most relevant pages, and drafts a sourced reply for the agent to review before sending.',
    iconId: 'brand/google-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_sheets-0',
    blockType: 'google_sheets',
    label: 'Google Sheets approval gate',
    prompt:
        'Build a workflow that watches a Google Sheets row for a status change to "review", posts the row context to Slack with approval buttons, and writes the decision back.',
    iconId: 'brand/google-sheets-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'google-sheets',
  ),
  SuggestionTemplate(
    id: 'google_sheets-1',
    blockType: 'google_sheets',
    label: 'Google Sheets to Stripe payouts',
    prompt:
        'Create a workflow that reads a Google Sheets payouts ledger, validates each row, processes Stripe payouts in batches, and writes the result and Stripe ID back.',
    iconId: 'brand/google-sheets-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'google-sheets',
  ),
  SuggestionTemplate(
    id: 'google_sheets-2',
    blockType: 'google_sheets',
    label: 'Google Sheets CRM updater',
    prompt:
        'Build a scheduled workflow that pulls Salesforce opportunities, refreshes the Google Sheets spreadsheet that ops uses for weekly forecasting, and notes the last-updated timestamp.',
    iconId: 'brand/google-sheets-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'google-sheets',
  ),
  SuggestionTemplate(
    id: 'google_sheets-3',
    blockType: 'google_sheets',
    label: 'Google Sheets data validator',
    prompt:
        'Create a scheduled workflow that validates a Google Sheets spreadsheet against a typed schema, flags rows with errors, writes a remediation column, and emails the sheet owner.',
    iconId: 'brand/google-sheets-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'google-sheets',
  ),
  SuggestionTemplate(
    id: 'google_sheets-4',
    blockType: 'google_sheets',
    label: 'Google Sheets inventory sync',
    prompt:
        'Build a workflow that pulls Shopify inventory into Google Sheets hourly, calculates days-of-cover, and highlights items needing reorder for the ops team.',
    iconId: 'brand/google-sheets-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'google-sheets',
  ),
  SuggestionTemplate(
    id: 'google_sheets-5',
    blockType: 'google_sheets',
    label: 'Google Sheets forms cleanup',
    prompt:
        'Create a workflow that normalizes Google Sheets data submitted from Google Forms — title casing, phone formats, deduplication — and writes clean rows to a downstream sheet.',
    iconId: 'brand/google-sheets-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'google-sheets',
  ),
  SuggestionTemplate(
    id: 'google_sheets-6',
    blockType: 'google_sheets',
    label: 'Send Slack messages from Google Sheets',
    prompt:
        'Build a workflow that watches a Google Sheets spreadsheet for new rows or changes, then posts formatted Slack updates to keep stakeholders informed in real time.',
    iconId: 'brand/google-sheets-icon',
    modules: <String>['agent', 'workflows'],
    featured: true,
    providerId: 'google-sheets',
  ),
  SuggestionTemplate(
    id: 'google_sheets-7',
    blockType: 'google_sheets',
    label: 'Sync Google Sheets data into Notion',
    prompt:
        'Create an agent that reads rows from Google Sheets and transforms them into structured Notion database entries for richer documentation and cross-team project tracking.',
    iconId: 'brand/google-sheets-icon',
    modules: <String>['agent', 'workflows'],
    featured: true,
    providerId: 'google-sheets',
  ),
  SuggestionTemplate(
    id: 'google_slides-0',
    blockType: 'google_slides',
    label: 'Google Slides QBR generator',
    prompt:
        'Build a workflow that takes a customer account, pulls usage and support data, and generates a Google Slides QBR deck from a template with the metrics auto-filled.',
    iconId: 'brand/google-slides-icon',
    modules: <String>['agent', 'files', 'workflows'],
    providerId: 'google-drive',
  ),
  SuggestionTemplate(
    id: 'google_slides-1',
    blockType: 'google_slides',
    label: 'Google Slides weekly board update',
    prompt:
        'Create a scheduled weekly workflow that updates a Google Slides board deck with the latest KPIs from tables, swaps the cover image, and shares the link to the leadership thread.',
    iconId: 'brand/google-slides-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'google-drive',
  ),
  SuggestionTemplate(
    id: 'google_slides-2',
    blockType: 'google_slides',
    label: 'Google Slides case-study builder',
    prompt:
        'Build a workflow that takes a customer story brief and generates a Google Slides case-study deck from a template, including pull quotes, metrics, and a logo.',
    iconId: 'brand/google-slides-icon',
    modules: <String>['agent', 'files', 'workflows'],
    providerId: 'google-drive',
  ),
  SuggestionTemplate(
    id: 'google_slides-3',
    blockType: 'google_slides',
    label: 'Google Slides pitch personalizer',
    prompt:
        'Create a workflow that takes a Salesforce opportunity, generates a Google Slides pitch deck personalized to the account, and attaches it to the opportunity record.',
    iconId: 'brand/google-slides-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'google-drive',
  ),
  SuggestionTemplate(
    id: 'google_slides-4',
    blockType: 'google_slides',
    label: 'Google Slides training builder',
    prompt:
        'Build a workflow that takes a knowledge base topic, generates a Google Slides training deck with structured slides, talking points, and quiz slides at the end.',
    iconId: 'brand/google-slides-icon',
    modules: <String>['knowledge-base', 'agent', 'files', 'workflows'],
    providerId: 'google-drive',
  ),
  SuggestionTemplate(
    id: 'google_slides-5',
    blockType: 'google_slides',
    label: 'Google Slides exec metrics deck',
    prompt:
        'Create a scheduled monthly workflow that generates a Google Slides executive metrics deck from BigQuery and Stripe data, swaps the cover with the month, and shares it with leadership.',
    iconId: 'brand/google-slides-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
    providerId: 'google-drive',
  ),
  SuggestionTemplate(
    id: 'google_slides-6',
    blockType: 'google_slides',
    label: 'Google Slides win-loss recap',
    prompt:
        'Build a workflow that aggregates closed-won and closed-lost deals from Salesforce monthly, generates a Google Slides recap with patterns and insights, and emails it to the sales team.',
    iconId: 'brand/google-slides-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
    providerId: 'google-drive',
  ),
  SuggestionTemplate(
    id: 'google_tasks-0',
    blockType: 'google_tasks',
    label: 'Google Tasks digest',
    prompt:
        'Build a scheduled daily workflow that summarizes Google Tasks due today and tomorrow, and emails the user a prioritized digest each morning.',
    iconId: 'brand/google-tasks-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'google-tasks',
  ),
  SuggestionTemplate(
    id: 'google_tasks-1',
    blockType: 'google_tasks',
    label: 'Google Tasks from Gmail',
    prompt:
        'Create a workflow that watches Gmail for emails marked with a task label, extracts the action and due date, and creates a Google Tasks entry with a link back to the email.',
    iconId: 'brand/google-tasks-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'google-tasks',
  ),
  SuggestionTemplate(
    id: 'google_tasks-2',
    blockType: 'google_tasks',
    label: 'Google Tasks from meetings',
    prompt:
        'Build a workflow that runs after Google Meet meetings, extracts action items from the transcript, and creates Google Tasks entries for the owner with due dates.',
    iconId: 'brand/google-tasks-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'google-tasks',
  ),
  SuggestionTemplate(
    id: 'google_tasks-3',
    blockType: 'google_tasks',
    label: 'Google Tasks completion digest',
    prompt:
        'Create a scheduled weekly workflow that summarizes Google Tasks completed by the user, captures the throughput, and emails a personal productivity report.',
    iconId: 'brand/google-tasks-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'google-tasks',
  ),
  SuggestionTemplate(
    id: 'google_tasks-4',
    blockType: 'google_tasks',
    label: 'Google Tasks rolling cleanup',
    prompt:
        'Build a scheduled workflow that runs daily, archives Google Tasks completed more than 30 days ago, and surfaces tasks past their due date for re-prioritization.',
    iconId: 'brand/google-tasks-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'google-tasks',
  ),
  SuggestionTemplate(
    id: 'google_tasks-5',
    blockType: 'google_tasks',
    label: 'Google Tasks Slack sync',
    prompt:
        'Create a workflow that watches Slack for messages tagged with the saved-task emoji, captures the message and creates a Google Tasks entry with a link to the Slack thread.',
    iconId: 'brand/google-tasks-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'google-tasks',
  ),
  SuggestionTemplate(
    id: 'google_tasks-6',
    blockType: 'google_tasks',
    label: 'Google Tasks calendar block builder',
    prompt:
        'Build a workflow that on a Google Tasks creation also inserts a Google Calendar focus block with the task title, so the time is actually reserved.',
    iconId: 'brand/google-tasks-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'google-tasks',
  ),
  SuggestionTemplate(
    id: 'google_translate-0',
    blockType: 'google_translate',
    label: 'Google Translate doc localizer',
    prompt:
        'Create a workflow that watches a Google Drive folder of source-language docs, translates each into target languages with Google Translate while preserving structure, and writes the localized files back.',
    iconId: 'brand/google-translate-icon',
    modules: <String>['files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_translate-1',
    blockType: 'google_translate',
    label: 'Google Translate Intercom replier',
    prompt:
        'Build a workflow that detects the language of a new Intercom message, translates it to the agent language with Google Translate, drafts a reply, then translates the reply back before sending.',
    iconId: 'brand/google-translate-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_translate-2',
    blockType: 'google_translate',
    label: 'Google Translate + Hugging Face confidence',
    prompt:
        'Create a workflow that runs Google Translate then scores translation quality with a Hugging Face model, flags low-confidence segments for human review, and writes the scored output.',
    iconId: 'brand/google-translate-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_translate-3',
    blockType: 'google_translate',
    label: 'Google Translate + Mistral Parser localization',
    prompt:
        'Build a workflow that uses Mistral Parser to extract structured content from source-language PDFs and Google Translate to localize each section while preserving structure.',
    iconId: 'brand/google-translate-icon',
    modules: <String>['files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_translate-4',
    blockType: 'google_translate',
    label: 'Google Translate Confluence localization',
    prompt:
        'Create a workflow that watches Confluence pages tagged for localization, translates each into the target languages with Google Translate, and publishes localized copies.',
    iconId: 'brand/google-translate-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_translate-5',
    blockType: 'google_translate',
    label: 'Google Translate ticket auto-reply',
    prompt:
        'Build a workflow that on a new support ticket detects the customer\'s language with Google Translate, translates the message to English for the agent, drafts a reply, then translates the response back into the customer\'s language before sending.',
    iconId: 'brand/google-translate-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_translate-6',
    blockType: 'google_translate',
    label: 'Google Translate Slack translator',
    prompt:
        'Create a workflow that watches an international Slack channel, detects non-English messages with Google Translate, translates them to the team\'s language, and posts the translation in a thread so everyone stays in the loop.',
    iconId: 'brand/google-translate-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'google_vault-0',
    blockType: 'google_vault',
    label: 'Google Vault legal hold automator',
    prompt:
        'Build a scheduled workflow that polls Salesforce for new legal-hold instructions, creates a Google Vault matter and hold for the named custodians, and notifies legal with the hold details.',
    iconId: 'emcn/shield-check',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'google-vault',
  ),
  SuggestionTemplate(
    id: 'google_vault-1',
    blockType: 'google_vault',
    label: 'Google Vault hold auditor',
    prompt:
        'Create a scheduled workflow that lists Google Vault matters and holds, flags custodians missing expected holds, and writes the findings to a compliance review table.',
    iconId: 'emcn/shield-check',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'google-vault',
  ),
  SuggestionTemplate(
    id: 'google_vault-2',
    blockType: 'google_vault',
    label: 'Google Vault eDiscovery exporter',
    prompt:
        'Build a workflow that takes an eDiscovery request, runs a Google Vault search, exports the matters into structured archives, and writes the export manifest.',
    iconId: 'emcn/shield-check',
    modules: <String>['agent', 'files', 'workflows'],
    providerId: 'google-vault',
  ),
  SuggestionTemplate(
    id: 'google_vault-3',
    blockType: 'google_vault',
    label: 'Google Vault hold reviewer',
    prompt:
        'Create a scheduled workflow that lists Google Vault holds across matters, summarizes their custodians and scope, and writes a review report for the legal team to approve.',
    iconId: 'emcn/shield-check',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'google-vault',
  ),
  SuggestionTemplate(
    id: 'google_vault-4',
    blockType: 'google_vault',
    label: 'Google Vault sensitive-term exporter',
    prompt:
        'Build a scheduled workflow that creates Google Vault exports for sensitive search terms weekly, downloads the export results, and writes the matching items to a compliance review queue.',
    iconId: 'emcn/shield-check',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'google-vault',
  ),
  SuggestionTemplate(
    id: 'google_vault-5',
    blockType: 'google_vault',
    label: 'Google Vault export archiver',
    prompt:
        'Create a scheduled workflow that creates Google Vault matter exports, downloads the export files, archives them to S3 long-term storage, and writes the manifest to a compliance table.',
    iconId: 'emcn/shield-check',
    modules: <String>['scheduled', 'tables', 'files', 'agent', 'workflows'],
    providerId: 'google-vault',
  ),
  SuggestionTemplate(
    id: 'google_vault-6',
    blockType: 'google_vault',
    label: 'Google Vault custodian dashboard',
    prompt:
        'Build a scheduled monthly workflow that summarizes Google Vault holds and custodians, generates a status dashboard, and writes it to a legal review file.',
    iconId: 'emcn/shield-check',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
    providerId: 'google-vault',
  ),
  SuggestionTemplate(
    id: 'grafana-0',
    blockType: 'grafana',
    label: 'Grafana alert auto-context',
    prompt:
        'Build a scheduled workflow that reads Grafana alert-state annotations to find rules that just started firing, queries the underlying data source for the current metric value, summarizes the two together with an agent, and posts the enriched alert to PagerDuty and Slack.',
    iconId: 'brand/grafana-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'grafana-1',
    blockType: 'grafana',
    label: 'Grafana SLO scorecard',
    prompt:
        'Create a scheduled weekly workflow that runs SLI queries against a Grafana data source for each service, calculates error budget burn rates from the returned series, and writes a scorecard to a tables-based SRE review board.',
    iconId: 'brand/grafana-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'grafana-2',
    blockType: 'grafana',
    label: 'Grafana dashboard auditor',
    prompt:
        'Build a scheduled workflow that scans Grafana dashboards monthly for broken panels, unused dashboards, and missing alerts, and writes a cleanup queue for the platform team.',
    iconId: 'brand/grafana-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'grafana-3',
    blockType: 'grafana',
    label: 'Grafana metric export',
    prompt:
        'Create a workflow that runs a set of Grafana data source queries on schedule and writes the returned series into a Sim table, so the metrics can be combined with business data for unified reporting.',
    iconId: 'brand/grafana-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'grafana-4',
    blockType: 'grafana',
    label: 'Grafana incident annotator',
    prompt:
        'Build a scheduled workflow that polls PagerDuty for new incidents and adds Grafana annotations to relevant dashboards with the incident link, so engineers can see the context immediately on the timeline.',
    iconId: 'brand/grafana-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'grafana-5',
    blockType: 'grafana',
    label: 'Grafana on-call digest',
    prompt:
        'Create a scheduled daily workflow that summarizes the past 24 hours of Grafana alerts by service and severity, and posts an on-call digest to Slack each morning.',
    iconId: 'brand/grafana-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'grafana-6',
    blockType: 'grafana',
    label: 'Grafana + Linear feature-impact',
    prompt:
        'Build a scheduled workflow that queries a Grafana data source for latency and error rates, compares each series against the prior period to spot regressions, correlates them with recent Linear releases, and posts a regression review to the team Slack with the suspected change.',
    iconId: 'brand/grafana-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'grain-0',
    blockType: 'grain',
    label: 'Grain highlight to CRM',
    prompt:
        'Build a workflow that watches Grain meeting highlights, extracts customer quotes, and writes them to the linked Salesforce opportunity for deal context.',
    iconId: 'brand/grain-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'grain-1',
    blockType: 'grain',
    label: 'Grain customer-quote miner',
    prompt:
        'Create a workflow that processes Grain customer interview recordings, extracts notable quotes and themes, and writes them to a marketing research table.',
    iconId: 'brand/grain-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'grain-2',
    blockType: 'grain',
    label: 'Grain action-item ticket creator',
    prompt:
        'Build a workflow that extracts action items from Grain meeting transcripts, creates Linear tasks for each with owners and due dates, and pings the team in Slack.',
    iconId: 'brand/grain-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'grain-3',
    blockType: 'grain',
    label: 'Grain weekly call digest',
    prompt:
        'Create a scheduled weekly workflow that summarizes Grain meeting insights — common objections, decisions made, blockers — and posts a digest to the team Slack channel.',
    iconId: 'brand/grain-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'grain-4',
    blockType: 'grain',
    label: 'Grain coaching dashboard',
    prompt:
        'Build a scheduled weekly workflow that analyzes Grain sales calls per rep, calculates talk ratio, objection handling, and next-step clarity, and writes coaching notes to a table.',
    iconId: 'brand/grain-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'grain-5',
    blockType: 'grain',
    label: 'Grain + Notion knowledge sync',
    prompt:
        'Create a workflow that processes Grain meeting recordings, extracts decisions and learnings, and writes them as Notion pages tagged by topic for the team knowledge base.',
    iconId: 'brand/grain-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'grain-6',
    blockType: 'grain',
    label: 'Grain competitor mentions tracker',
    prompt:
        'Build a scheduled workflow that scans Grain sales transcripts for competitor mentions, logs the context and outcome to a competitive-intel table, and posts a weekly pattern summary to Slack.',
    iconId: 'brand/grain-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'grain_v2-0',
    blockType: 'grain_v2',
    label: 'Grain highlight to CRM',
    prompt:
        'Build a workflow that watches Grain meeting highlights, extracts customer quotes, and writes them to the linked Salesforce opportunity for deal context.',
    iconId: 'brand/grain-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'grain_v2-1',
    blockType: 'grain_v2',
    label: 'Grain customer-quote miner',
    prompt:
        'Create a workflow that processes Grain customer interview recordings, extracts notable quotes and themes, and writes them to a marketing research table.',
    iconId: 'brand/grain-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'grain_v2-2',
    blockType: 'grain_v2',
    label: 'Grain action-item ticket creator',
    prompt:
        'Build a workflow that extracts action items from Grain meeting transcripts, creates Linear tasks for each with owners and due dates, and pings the team in Slack.',
    iconId: 'brand/grain-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'grain_v2-3',
    blockType: 'grain_v2',
    label: 'Grain weekly call digest',
    prompt:
        'Create a scheduled weekly workflow that summarizes Grain meeting insights — common objections, decisions made, blockers — and posts a digest to the team Slack channel.',
    iconId: 'brand/grain-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'grain_v2-4',
    blockType: 'grain_v2',
    label: 'Grain coaching dashboard',
    prompt:
        'Build a scheduled weekly workflow that analyzes Grain sales calls per rep, calculates talk ratio, objection handling, and next-step clarity, and writes coaching notes to a table.',
    iconId: 'brand/grain-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'grain_v2-5',
    blockType: 'grain_v2',
    label: 'Grain + Notion knowledge sync',
    prompt:
        'Create a workflow that processes Grain meeting recordings, extracts decisions and learnings, and writes them as Notion pages tagged by topic for the team knowledge base.',
    iconId: 'brand/grain-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'grain_v2-6',
    blockType: 'grain_v2',
    label: 'Grain competitor mentions tracker',
    prompt:
        'Build a scheduled workflow that scans Grain sales transcripts for competitor mentions, logs the context and outcome to a competitive-intel table, and posts a weekly pattern summary to Slack.',
    iconId: 'brand/grain-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'granola-0',
    blockType: 'granola',
    label: 'Granola meeting brief',
    prompt:
        'Build a scheduled workflow that reads upcoming meetings from Granola notes, researches attendees and topic with Apollo, and posts a prep brief to Slack before each meeting.',
    iconId: 'brand/granola-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'granola-1',
    blockType: 'granola',
    label: 'Granola action-item ticket creator',
    prompt:
        'Create a workflow that extracts action items from Granola meeting notes, creates Linear or Asana tasks for each with owners and due dates, and posts a summary to Slack.',
    iconId: 'brand/granola-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'granola-2',
    blockType: 'granola',
    label: 'Granola CRM updater',
    prompt:
        'Build a workflow that runs after a Granola sales meeting, summarizes the meeting notes into a deal-ready summary, and updates the linked Salesforce or HubSpot opportunity.',
    iconId: 'brand/granola-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'granola-3',
    blockType: 'granola',
    label: 'Granola weekly digest',
    prompt:
        'Create a scheduled weekly workflow that aggregates Granola meeting notes, identifies recurring themes and decisions, and writes a digest to the team Slack channel.',
    iconId: 'brand/granola-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'granola-4',
    blockType: 'granola',
    label: 'Granola + Notion publisher',
    prompt:
        'Build a scheduled workflow that polls Granola for new meeting notes, generates a polished meeting-notes page in Notion under the right team space, and links the original Granola note.',
    iconId: 'brand/granola-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'granola-5',
    blockType: 'granola',
    label: 'Granola customer-interview extractor',
    prompt:
        'Create a workflow that processes Granola customer-interview notes, extracts notable quotes and pain points, and writes them to a tables-based research log.',
    iconId: 'brand/granola-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'granola-6',
    blockType: 'granola',
    label: 'Granola decision-log keeper',
    prompt:
        'Build a workflow that scans Granola meeting notes for decisions made, writes each to a tables-based decision log with date, owner, and context, and shares the link.',
    iconId: 'brand/granola-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'greenhouse-0',
    blockType: 'greenhouse',
    label: 'Greenhouse pipeline monitor',
    prompt:
        'Build a scheduled workflow that syncs open jobs and candidates from Greenhouse to a tracking table daily, flags candidates who have been in the same stage for more than 5 days, and sends a Slack summary to hiring managers with pipeline stats and bottlenecks.',
    iconId: 'brand/greenhouse-icon',
    modules: <String>['tables', 'scheduled', 'agent', 'workflows'],
    providerId: 'greenhouse',
  ),
  SuggestionTemplate(
    id: 'greenhouse-1',
    blockType: 'greenhouse',
    label: 'Greenhouse to onboarding kickoff',
    prompt:
        'Build a workflow that fires when a Greenhouse application is marked hired, gathers the new hire profile, kicks off an onboarding plan in a table, schedules week-one meetings via Google Calendar, and posts a welcome announcement to Slack.',
    iconId: 'brand/greenhouse-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'greenhouse',
  ),
  SuggestionTemplate(
    id: 'greenhouse-2',
    blockType: 'greenhouse',
    label: 'Greenhouse candidate enricher',
    prompt:
        'Create a workflow that watches for new Greenhouse candidates, enriches each profile with LinkedIn background, GitHub activity, and public writing, and writes a structured research summary to a recruiting table for recruiters to review.',
    iconId: 'brand/greenhouse-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'greenhouse',
  ),
  SuggestionTemplate(
    id: 'greenhouse-3',
    blockType: 'greenhouse',
    label: 'Greenhouse interview scheduler',
    prompt:
        'Build a workflow that runs after a Greenhouse application reaches the interview stage, finds the right interviewer panel based on job stage, proposes time slots from Google Calendar, drafts a coordination email to the candidate, and confirms the booking in a tracking table.',
    iconId: 'brand/greenhouse-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'greenhouse',
  ),
  SuggestionTemplate(
    id: 'greenhouse-4',
    blockType: 'greenhouse',
    label: 'Greenhouse offer drafter',
    prompt:
        'Create a workflow that takes an approved Greenhouse application, pulls compensation bands from a knowledge base, drafts a tailored offer letter file, prepares an explanation email, and routes both to the hiring manager for review before sending to the candidate.',
    iconId: 'brand/greenhouse-icon',
    modules: <String>['knowledge-base', 'files', 'agent', 'workflows'],
    providerId: 'greenhouse',
  ),
  SuggestionTemplate(
    id: 'greenhouse-5',
    blockType: 'greenhouse',
    label: 'Greenhouse rejection follow-up',
    prompt:
        'Build a workflow that runs when a Greenhouse candidate is rejected, drafts a warm and respectful rejection email tailored to how far they progressed, sends it via Gmail, and logs the candidate with their interest areas to a future-talent table for re-engagement.',
    iconId: 'brand/greenhouse-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'greenhouse',
  ),
  SuggestionTemplate(
    id: 'greenhouse-6',
    blockType: 'greenhouse',
    label: 'Greenhouse interview prep packet',
    prompt:
        'Create a workflow that runs the morning of every Greenhouse interview, pulls the candidate profile, prior interview notes, and job rubric, assembles a one-page prep file for the interviewer, and emails it with a Slack DM reminder thirty minutes before the slot.',
    iconId: 'brand/greenhouse-icon',
    modules: <String>['agent', 'files', 'workflows'],
    providerId: 'greenhouse',
  ),
  SuggestionTemplate(
    id: 'greenhouse_v2-0',
    blockType: 'greenhouse_v2',
    label: 'Greenhouse pipeline report',
    prompt:
        'Build a scheduled workflow that lists open Greenhouse jobs and active applications, follows every cursor page, joins current interview stages and time-in-stage records, and writes per-role counts and stalled stages to a recruiting table. Send the report to Slack.',
    iconId: 'brand/greenhouse-icon',
    modules: <String>['tables', 'workflows'],
    providerId: 'greenhouse',
  ),
  SuggestionTemplate(
    id: 'greenhouse_v2-1',
    blockType: 'greenhouse_v2',
    label: 'Greenhouse candidate intake',
    prompt:
        'Build a workflow that checks Greenhouse candidates by email before creating an approved intake profile, adds an application to the selected job, records the intake note, and stores the returned identifiers for reconciliation.',
    iconId: 'brand/greenhouse-icon',
    modules: <String>['tables', 'workflows'],
    providerId: 'greenhouse',
  ),
  SuggestionTemplate(
    id: 'greenhouse_v2-2',
    blockType: 'greenhouse_v2',
    label: 'Greenhouse interviewer brief',
    prompt:
        'Build a workflow that lists upcoming Greenhouse interviews, retrieves the related candidate, application, job, notes, and attachment metadata, and drafts a sourced preparation brief for interviewer review.',
    iconId: 'brand/greenhouse-icon',
    modules: <String>['agent', 'files', 'workflows'],
    providerId: 'greenhouse',
  ),
  SuggestionTemplate(
    id: 'greenhouse_v2-3',
    blockType: 'greenhouse_v2',
    label: 'Greenhouse hiring ownership audit',
    prompt:
        'Build a scheduled workflow that lists open jobs, hiring managers, job owners, departments, offices, and users. Join their IDs into a role-ownership table and flag jobs missing a recruiter or hiring manager.',
    iconId: 'brand/greenhouse-icon',
    modules: <String>['tables', 'workflows'],
    providerId: 'greenhouse',
  ),
  SuggestionTemplate(
    id: 'greenhouse_v2-4',
    blockType: 'greenhouse_v2',
    label: 'Greenhouse scorecard follow-up',
    prompt:
        'Build a workflow that lists completed Greenhouse interviews and related scorecards, identifies pending feedback, and prepares a Slack reminder for the recruiting coordinator to review.',
    iconId: 'brand/greenhouse-icon',
    modules: <String>['tables', 'workflows'],
    providerId: 'greenhouse',
  ),
  SuggestionTemplate(
    id: 'greenhouse_v2-5',
    blockType: 'greenhouse_v2',
    label: 'Greenhouse approved candidate updates',
    prompt:
        'Build a workflow that reads a Greenhouse candidate profile, merges approved contact changes into the complete existing arrays, updates only the intended fields, and records a note describing the approved changes.',
    iconId: 'brand/greenhouse-icon',
    modules: <String>['workflows'],
    providerId: 'greenhouse',
  ),
  SuggestionTemplate(
    id: 'greenhouse_v2-6',
    blockType: 'greenhouse_v2',
    label: 'Greenhouse prospect organization',
    prompt:
        'Build a workflow that lists Greenhouse prospect pools and stages, creates an approved prospect application for an existing candidate, applies the selected candidate tags, and records the application and applied-tag identifiers in a tracking table.',
    iconId: 'brand/greenhouse-icon',
    modules: <String>['tables', 'workflows'],
    providerId: 'greenhouse',
  ),
  SuggestionTemplate(
    id: 'greptile-0',
    blockType: 'greptile',
    label: 'Greptile Slack Q&A bot',
    prompt:
        'Build a workflow that monitors a Slack channel for code questions, routes them to Greptile against the relevant repository, and replies in-thread with the answer and the cited files.',
    iconId: 'brand/greptile-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'greptile-1',
    blockType: 'greptile',
    label: 'Greptile onboarding explainer',
    prompt:
        'Create a workflow where a new engineer asks how a part of the codebase works, Greptile answers against the indexed repository with cited files, and the explanation is saved to a Google Doc.',
    iconId: 'brand/greptile-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'greptile-2',
    blockType: 'greptile',
    label: 'Greptile PR review context',
    prompt:
        'Build a workflow that takes a pull request, asks Greptile how the changed code interacts with the rest of the repository, and writes a review comment summarizing impact and risks with cited files.',
    iconId: 'emcn/clipboard-list',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'harmonic-0',
    blockType: 'harmonic',
    label: 'Harmonic contact finder',
    prompt:
        'Build a chat-driven workflow that turns a sourcing request such as "find FDEs in enterprise software" into a Harmonic Scout search and writes the normalized contacts to a table for review.',
    iconId: 'brand/harmonic-icon',
    modules: <String>['agent', 'tables', 'workflows'],
    featured: true,
  ),
  SuggestionTemplate(
    id: 'harmonic-1',
    blockType: 'harmonic',
    label: 'Harmonic saved search sync',
    prompt:
        'Create a scheduled workflow that resolves a team-visible Harmonic people saved search, pages every result, compares person URNs with the prior table snapshot, and posts newly seen contacts to Slack.',
    iconId: 'brand/harmonic-icon',
    modules: <String>['scheduled', 'tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'harmonic-2',
    blockType: 'harmonic',
    label: 'Harmonic contact hydrator',
    prompt:
        'Build a workflow that accepts Harmonic person URNs from an earlier search, batches them in groups of 500, retrieves normalized contact records, and writes names, roles, companies, emails, and LinkedIn URLs to a table.',
    iconId: 'brand/harmonic-icon',
    modules: <String>['tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'harmonic-3',
    blockType: 'harmonic',
    label: 'Harmonic sourcing shortlist',
    prompt:
        'Create an agent that searches Harmonic Scout for a sourcing thesis, scores the normalized contacts against explicit role, company, and location criteria, and writes the ranked shortlist with evidence to a review table.',
    iconId: 'brand/harmonic-icon',
    modules: <String>['agent', 'tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'harmonic-4',
    blockType: 'harmonic',
    label: 'Harmonic CRM prospect route',
    prompt:
        'Build a workflow that searches Harmonic Scout for technical buyers at target accounts, filters contacts with a usable email or LinkedIn URL, deduplicates them by person URN, and writes qualified prospects to Salesforce.',
    iconId: 'brand/harmonic-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'harmonic-5',
    blockType: 'harmonic',
    label: 'Harmonic contact coverage audit',
    prompt:
        'Create a workflow that resolves a team-visible Harmonic people saved search, pages all results, hydrates URN-only records in batches, flags duplicates and missing contact fields, and writes the review queue to Google Sheets.',
    iconId: 'brand/harmonic-icon',
    modules: <String>['tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'harmonic-6',
    blockType: 'harmonic',
    label: 'Harmonic talent scout',
    prompt:
        'Build an agent that uses Harmonic Scout to find candidates with a requested title, industry background, and geography, ranks the normalized contacts, and sends the shortlist to a Slack hiring channel.',
    iconId: 'brand/harmonic-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'harmonic-7',
    blockType: 'harmonic',
    label: 'Harmonic batch enrichment',
    prompt:
        'Create a workflow that accepts Harmonic person IDs and URNs from a table, deduplicates and splits them into batches of at most 500, retrieves normalized contacts with Batch Get People, and writes hydrated and unmatched rows separately.',
    iconId: 'brand/harmonic-icon',
    modules: <String>['tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'helpscout-0',
    blockType: 'helpscout',
    label: 'Help Scout Reply Drafter',
    prompt:
        'When a customer replies to a Help Scout conversation, read the conversation threads, search our knowledge base for the answer, and save a draft reply on the conversation for an agent to review.',
    iconId: 'brand/help-scout-icon',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
    providerId: 'helpscout',
  ),
  SuggestionTemplate(
    id: 'helpscout-1',
    blockType: 'helpscout',
    label: 'New Conversation Triage',
    prompt:
        'When a Help Scout conversation is created, classify it by topic and urgency, set the matching tags, assign it to the right teammate, and add an internal note explaining the routing decision.',
    iconId: 'brand/help-scout-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'helpscout',
  ),
  SuggestionTemplate(
    id: 'helpscout-2',
    blockType: 'helpscout',
    label: 'Daily Support Queue Digest',
    prompt:
        'Every weekday morning, list active and pending Help Scout conversations, group them by inbox and assignee, flag the ones customers have waited on longest, and post the digest to the support team in Slack.',
    iconId: 'brand/help-scout-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'helpscout',
  ),
  SuggestionTemplate(
    id: 'helpscout-3',
    blockType: 'helpscout',
    label: 'Stale Pending Follow-Up',
    prompt:
        'Each day, find Help Scout conversations that have been pending for more than five days, add a note summarizing the last customer message, and close the ones where the customer confirmed the issue is resolved.',
    iconId: 'brand/help-scout-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'helpscout',
  ),
  SuggestionTemplate(
    id: 'helpscout-4',
    blockType: 'helpscout',
    label: 'Customer Context Lookup',
    prompt:
        'When given a customer email, search Help Scout customers, read the customer profile and their recent conversations, and return a short history with open issues and conversation links.',
    iconId: 'brand/help-scout-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'helpscout',
  ),
  SuggestionTemplate(
    id: 'helpscout-5',
    blockType: 'helpscout',
    label: 'Support Tag Trends',
    prompt:
        'Every Friday, list Help Scout conversations created this week, count them by tag and inbox, compare with last week, and write a summary of rising topics for the product team.',
    iconId: 'brand/help-scout-icon',
    modules: <String>['scheduled', 'agent', 'tables'],
    providerId: 'helpscout',
  ),
  SuggestionTemplate(
    id: 'helpscout-6',
    blockType: 'helpscout',
    label: 'Escalate Bug Reports',
    prompt:
        'When a Help Scout conversation is tagged bug, read its threads, write a reproducible bug summary, file it as a Linear issue, and add an internal note on the conversation linking the issue.',
    iconId: 'brand/help-scout-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'helpscout',
  ),
  SuggestionTemplate(
    id: 'helpscout-7',
    blockType: 'helpscout',
    label: 'New Customer Enrichment',
    prompt:
        'When a customer is created in Help Scout, look up their company from the email domain and update the customer job title, location, and notes so agents have context on the first reply.',
    iconId: 'brand/help-scout-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'helpscout',
  ),
  SuggestionTemplate(
    id: 'hex-0',
    blockType: 'hex',
    label: 'Hex project notebook runner',
    prompt:
        'Create a scheduled workflow that runs a Hex notebook with parameters every morning, waits for the run to finish, and posts a summary with the published notebook link to a Slack data channel.',
    iconId: 'brand/hex-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'hex-1',
    blockType: 'hex',
    label: 'Hex anomaly digest',
    prompt:
        'Build a workflow that runs a Hex notebook for anomaly detection on key metrics nightly, captures detected anomalies into a table, and pages the on-call data team on Slack for severe deltas.',
    iconId: 'brand/hex-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'hex-2',
    blockType: 'hex',
    label: 'Hex executive metrics email',
    prompt:
        'Create a scheduled weekly workflow that runs a Hex executive dashboard notebook, summarizes the run results, and emails a snapshot with the dashboard link to the leadership distribution list every Monday morning.',
    iconId: 'brand/hex-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'hex-3',
    blockType: 'hex',
    label: 'Hex + Tinybird realtime data app',
    prompt:
        'Create a workflow that powers a Hex data app with Tinybird realtime data, refreshes the dashboard on schedule, and writes usage analytics to a table.',
    iconId: 'brand/hex-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'hex-4',
    blockType: 'hex',
    label: 'Hex + Stripe revenue notebook',
    prompt:
        'Build a scheduled workflow that runs a Hex notebook over Stripe payment data daily, captures MRR, churn, and expansion metrics, and posts a summary with the notebook link to a Slack data channel.',
    iconId: 'brand/hex-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'hex-5',
    blockType: 'hex',
    label: 'Hex + Amplitude product notebook',
    prompt:
        'Create a scheduled workflow that runs a Hex notebook joining Amplitude data with internal sources weekly, captures retention and feature adoption, and emails a summary with the notebook link to the product team.',
    iconId: 'brand/hex-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'hex-6',
    blockType: 'hex',
    label: 'Hex run failure monitor',
    prompt:
        'Build a workflow that lists recent Hex project runs every hour, checks each run status, and when a scheduled notebook fails pulls the error, summarizes the likely cause with an agent, and posts a Slack alert with a link to the run.',
    iconId: 'brand/hex-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'hubspot-0',
    blockType: 'hubspot',
    label: 'HubSpot deal search',
    prompt:
        'Create a knowledge base connected to my HubSpot account so all deals, contacts, and activity history are automatically synced and searchable. Then build an agent I can ask things like "what happened with the Stripe integration deal?" or "which deals closed last quarter over \$50k?" and get answers with HubSpot record links.',
    iconId: 'brand/hubspot-icon',
    modules: <String>['knowledge-base', 'agent'],
    providerId: 'hubspot',
  ),
  SuggestionTemplate(
    id: 'hubspot-1',
    blockType: 'hubspot',
    label: 'HubSpot win/loss analyzer',
    prompt:
        'Build a workflow that pulls closed deals from HubSpot each week, analyzes patterns in wins vs losses — deal size, industry, sales cycle length, objections — and generates a report file with actionable insights on what to change. Schedule it to run every Monday.',
    iconId: 'brand/hubspot-icon',
    modules: <String>['agent', 'files', 'scheduled', 'workflows'],
    providerId: 'hubspot',
  ),
  SuggestionTemplate(
    id: 'hubspot-2',
    blockType: 'hubspot',
    label: 'Get HubSpot deal alerts in Slack',
    prompt:
        'Build a workflow that watches HubSpot for deal stage changes, new contacts, and revenue milestones, then posts instant Slack notifications to your sales team.',
    iconId: 'brand/hubspot-icon',
    modules: <String>['agent', 'workflows'],
    featured: true,
    providerId: 'hubspot',
  ),
  SuggestionTemplate(
    id: 'hubspot-3',
    blockType: 'hubspot',
    label: 'Send personalised emails from HubSpot events',
    prompt:
        'Build a workflow that triggers whenever a HubSpot contact enters a new lifecycle stage and sends a personalised Gmail message tailored to that stage.',
    iconId: 'brand/hubspot-icon',
    modules: <String>['agent', 'workflows'],
    featured: true,
    providerId: 'hubspot',
  ),
  SuggestionTemplate(
    id: 'hubspot-4',
    blockType: 'hubspot',
    label: 'HubSpot lead enrichment and dedupe',
    prompt:
        'Build a workflow that on a new HubSpot contact searches for existing duplicates, enriches the record with company size, industry, and verified email, and updates the contact and its associated company with the cleaned data.',
    iconId: 'brand/hubspot-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'hubspot',
  ),
  SuggestionTemplate(
    id: 'hubspot-5',
    blockType: 'hubspot',
    label: 'HubSpot pipeline weekly digest',
    prompt:
        'Create a scheduled weekly workflow that lists HubSpot deals by stage, computes movement and at-risk deals with an agent, logs the snapshot to a table, and emails a pipeline summary to the sales leadership team.',
    iconId: 'brand/hubspot-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'hubspot',
  ),
  SuggestionTemplate(
    id: 'hubspot-6',
    blockType: 'hubspot',
    label: 'HubSpot ticket triage',
    prompt:
        'Build a workflow that on a new HubSpot support ticket classifies priority and topic, adds a triage note, associates it with the right company, and posts an alert to the support Slack channel for high-priority cases.',
    iconId: 'brand/hubspot-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'hubspot',
  ),
  SuggestionTemplate(
    id: 'hubspot-7',
    blockType: 'hubspot',
    label: 'Backfill HubSpot contact email history from Gmail',
    prompt:
        'Build a workflow that finds HubSpot contacts in the lead stage with no logged email activity, searches my Gmail for each person’s thread, and logs it back to HubSpot as an email engagement associated with the contact.',
    iconId: 'brand/hubspot-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'hubspot',
  ),
  SuggestionTemplate(
    id: 'huggingface-0',
    blockType: 'huggingface',
    label: 'Hugging Face row classifier',
    prompt:
        'Build a workflow that runs each row in a table through a Hugging Face chat model with custom labels in the prompt, writes the predicted label and a confidence rating back, and flags low-confidence rows for review.',
    iconId: 'brand/hugging-face-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'huggingface-1',
    blockType: 'huggingface',
    label: 'Hugging Face sentiment scorer',
    prompt:
        'Create a workflow that scores customer feedback with a Hugging Face chat model, writes sentiment and score columns back to the table, and pings Slack on a sudden negative spike.',
    iconId: 'brand/hugging-face-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'huggingface-2',
    blockType: 'huggingface',
    label: 'Hugging Face candidate reranker',
    prompt:
        'Create a retrieval pipeline that fetches top-50 candidates from a knowledge base, reranks them with a Hugging Face chat model scoring relevance, and returns the top-5 to the answering agent for higher precision.',
    iconId: 'brand/hugging-face-icon',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'huggingface-3',
    blockType: 'huggingface',
    label: 'Hugging Face PII redactor',
    prompt:
        'Build a workflow that runs a Hugging Face chat model over text uploads to detect PII, redacts the sensitive entities, and writes the cleaned text to a downstream table.',
    iconId: 'brand/hugging-face-icon',
    modules: <String>['files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'huggingface-4',
    blockType: 'huggingface',
    label: 'Hugging Face open-model summarizer',
    prompt:
        'Create a workflow that on a new document fetches the text and runs it through a Hugging Face chat model to produce a concise summary and key takeaways, then writes the result back to a table — keeping the workload on open-weight models you control.',
    iconId: 'brand/hugging-face-icon',
    modules: <String>['files', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'huggingface-5',
    blockType: 'huggingface',
    label: 'Hugging Face feedback classifier',
    prompt:
        'Build a workflow that reads new customer feedback rows, uses a Hugging Face chat model to classify sentiment and theme, writes the labels back to the table, and posts a Slack alert when negative feedback spikes.',
    iconId: 'brand/hugging-face-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'huggingface-6',
    blockType: 'huggingface',
    label: 'Hugging Face model A/B harness',
    prompt:
        'Create a workflow that runs the same prompt through a Hugging Face open model and a hosted model side by side, compares the outputs with a grading agent, and logs quality, latency, and cost to a table for evaluation.',
    iconId: 'brand/hugging-face-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'hunter-0',
    blockType: 'hunter',
    label: 'Hunter email finder',
    prompt:
        'Build a workflow that takes a target company and role from a table, runs Hunter to find the matching email, validates it, and writes the verified contact back.',
    iconId: 'brand/hunter-io-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'hunter-1',
    blockType: 'hunter',
    label: 'Hunter email verifier',
    prompt:
        'Create a workflow that runs a list of email addresses through Hunter verification, removes invalid emails, and writes a clean list for outbound sends.',
    iconId: 'brand/hunter-io-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'hunter-2',
    blockType: 'hunter',
    label: 'Hunter + Email Bison outbound',
    prompt:
        'Build a workflow that uses Hunter to find prospect emails, validates each, and pushes valid prospects into an active Email Bison campaign.',
    iconId: 'brand/hunter-io-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'hunter-3',
    blockType: 'hunter',
    label: 'Hunter domain finder',
    prompt:
        'Create a workflow that takes a list of company names, finds the matching domains via Hunter, and enriches the rows so the CRM has accurate domain data.',
    iconId: 'brand/hunter-io-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'hunter-4',
    blockType: 'hunter',
    label: 'Hunter event-list enricher',
    prompt:
        'Build a workflow that takes a Luma event registrants list, finds their work emails via Hunter, and writes the verified emails into HubSpot for followup.',
    iconId: 'brand/hunter-io-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'hunter-5',
    blockType: 'hunter',
    label: 'Hunter CRM gap-filler',
    prompt:
        'Create a scheduled workflow that finds HubSpot contacts missing email addresses, looks them up via Hunter, validates each, and updates the contact record.',
    iconId: 'brand/hunter-io-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'hunter-6',
    blockType: 'hunter',
    label: 'Hunter + Apollo prospect builder',
    prompt:
        'Build a workflow that runs an Apollo search for an ICP, finds verified emails via Hunter, and writes the deliverable prospect list to a sender table.',
    iconId: 'brand/hunter-io-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'iam-0',
    blockType: 'iam',
    label: 'IAM permission drift detector',
    prompt:
        'Build a scheduled workflow that diffs AWS IAM policies against the Terraform source of truth, alerts on drift, and writes the drift report to a security Slack channel.',
    iconId: 'brand/iam-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'iam-1',
    blockType: 'iam',
    label: 'IAM wildcard policy auditor',
    prompt:
        'Create a scheduled workflow that scans AWS IAM policies for wildcard permissions, scores each by blast radius, and writes a remediation queue to a security table.',
    iconId: 'brand/iam-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'iam-2',
    blockType: 'iam',
    label: 'IAM access-review automator',
    prompt:
        'Build a scheduled quarterly workflow that posts AWS IAM access-review requests to role owners in Slack, captures attestations, and writes the audit log to a compliance table.',
    iconId: 'brand/iam-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'iam-3',
    blockType: 'iam',
    label: 'IAM stale-key sweeper',
    prompt:
        'Create a scheduled workflow that reviews IAM users for aged access keys, notifies the owner via Slack, and rotates the key with a fresh one or removes it after a grace period.',
    iconId: 'brand/iam-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'iam-4',
    blockType: 'iam',
    label: 'IAM unused-role cleaner',
    prompt:
        'Build a scheduled monthly workflow that finds IAM roles with no recent activity, requires owner approval in Slack, and removes the role to reduce attack surface.',
    iconId: 'brand/iam-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'iam-5',
    blockType: 'iam',
    label: 'IAM least-privilege recommender',
    prompt:
        'Create a workflow that simulates IAM principal policies against expected actions, generates least-privilege policy suggestions for over-permissioned roles, and opens Linear tickets for engineers to apply.',
    iconId: 'brand/iam-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'iam-6',
    blockType: 'iam',
    label: 'IAM policy guardrail watcher',
    prompt:
        'Build a scheduled workflow that snapshots AWS IAM managed policies and role attachments, classifies risk on each change, and pings the security team in Slack when a change broadens permissions.',
    iconId: 'brand/iam-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'identity_center-0',
    blockType: 'identity_center',
    label: 'Identity Center access-review',
    prompt:
        'Build a scheduled quarterly workflow that surfaces AWS Identity Center permission sets and group memberships, requests owner attestation in Slack, and writes the audit log to a compliance table.',
    iconId: 'brand/identity-center-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'identity_center-1',
    blockType: 'identity_center',
    label: 'Identity Center new-hire onboarder',
    prompt:
        'Create a workflow that on a Workday new-hire event provisions AWS Identity Center permission sets based on role, and writes the assignment to a tracking table.',
    iconId: 'brand/identity-center-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'identity_center-2',
    blockType: 'identity_center',
    label: 'Identity Center offboarder',
    prompt:
        'Build a workflow that on a Workday termination revokes the user’s AWS Identity Center assignments and writes the action log to the security audit table.',
    iconId: 'brand/identity-center-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'identity_center-3',
    blockType: 'identity_center',
    label: 'Identity Center assignment monitor',
    prompt:
        'Create a scheduled workflow that snapshots AWS Identity Center account assignments and permission sets, flags new or broadened access, and pings the security Slack channel on changes.',
    iconId: 'brand/identity-center-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'identity_center-4',
    blockType: 'identity_center',
    label: 'Identity Center permission-set drift',
    prompt:
        'Build a scheduled workflow that diffs AWS Identity Center permission sets against the Terraform source of truth, alerts on drift, and writes the report.',
    iconId: 'brand/identity-center-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'identity_center-5',
    blockType: 'identity_center',
    label: 'Identity Center orphaned-access finder',
    prompt:
        'Create a scheduled workflow that lists AWS Identity Center account assignments, flags principals with stale or unexpected access, emails owners for confirmation, and writes the findings to a security dashboard table.',
    iconId: 'brand/identity-center-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'identity_center-6',
    blockType: 'identity_center',
    label: 'Identity Center compliance reporter',
    prompt:
        'Build a scheduled workflow that produces an AWS Identity Center compliance report — permission sets, group memberships, and account assignments — and writes the file for auditors.',
    iconId: 'brand/identity-center-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'incidentio-0',
    blockType: 'incidentio',
    label: 'incident.io commander',
    prompt:
        'Build a scheduled workflow that polls incident.io for newly declared incidents, opens a Slack war-room for each, invites responders from the on-call schedule, pulls related PagerDuty alerts, and pins the runbook.',
    iconId: 'brand/incidentio-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'incidentio-1',
    blockType: 'incidentio',
    label: 'incident.io postmortem starter',
    prompt:
        'Create a scheduled workflow that polls incident.io for recently resolved incidents, pulls the Slack thread, related Sentry errors, and deploy timeline, then drafts a postmortem doc in Google Docs.',
    iconId: 'brand/incidentio-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'incidentio-2',
    blockType: 'incidentio',
    label: 'incident.io action-item tracker',
    prompt:
        'Build a workflow that watches incident.io for new follow-up actions, creates Linear tickets for each, and writes a tracking table that surfaces overdue actions on a weekly digest.',
    iconId: 'brand/incidentio-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'incidentio-3',
    blockType: 'incidentio',
    label: 'incident.io weekly digest',
    prompt:
        'Create a scheduled weekly workflow that summarizes incident.io activity — declared incidents, MTTR, top affected services, action-item completion rate — and posts to Slack.',
    iconId: 'brand/incidentio-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'incidentio-4',
    blockType: 'incidentio',
    label: 'incident.io customer comms drafter',
    prompt:
        'Build a workflow that during a high-severity incident.io incident drafts customer status-page copy and a tailored email update, holds for approval, and dispatches once approved.',
    iconId: 'brand/incidentio-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'incidentio-5',
    blockType: 'incidentio',
    label: 'incident.io SLO impact mapper',
    prompt:
        'Create a workflow that on each incident.io incident maps impacted services to active SLOs, calculates SLO burn, and writes the impact analysis back to the incident timeline.',
    iconId: 'brand/incidentio-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'incidentio-6',
    blockType: 'incidentio',
    label: 'incident.io noise filter',
    prompt:
        'Build a workflow that pulls incident.io declared incidents, classifies a subset as low-impact noise, auto-resolves them after auditing, and writes a noise-rate metric to a table.',
    iconId: 'brand/incidentio-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'infisical-0',
    blockType: 'infisical',
    label: 'Infisical secret rotation orchestrator',
    prompt:
        'Build a scheduled workflow that lists Infisical secrets, generates fresh values for those due for rotation, updates them across each environment, and writes rotation status to a compliance table.',
    iconId: 'brand/infisical-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'infisical-1',
    blockType: 'infisical',
    label: 'Infisical environment drift detector',
    prompt:
        'Create a scheduled workflow that diffs Infisical environments against expected schemas, alerts on missing or extra secrets, and writes a remediation queue.',
    iconId: 'brand/infisical-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'infisical-2',
    blockType: 'infisical',
    label: 'Infisical env bootstrapper',
    prompt:
        'Build a workflow that on a Workday new-hire event creates the standard set of Infisical secrets for the new engineer’s scoped dev environment from a template, and writes the provisioning record to a table.',
    iconId: 'brand/infisical-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'infisical-3',
    blockType: 'infisical',
    label: 'Infisical offboarding rotation',
    prompt:
        'Create a workflow that on a Workday termination rotates the shared Infisical secrets the departing engineer had access to by generating new values and updating them across environments, then writes the action log to a table.',
    iconId: 'brand/infisical-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'infisical-4',
    blockType: 'infisical',
    label: 'Infisical CI sync',
    prompt:
        'Build a workflow that mirrors Infisical secrets into GitHub Actions environments for CI deploys, keeping the secret store as the single source of truth.',
    iconId: 'brand/infisical-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'infisical-5',
    blockType: 'infisical',
    label: 'Infisical secret-inventory reviewer',
    prompt:
        'Create a scheduled quarterly workflow that lists Infisical secrets per project and environment, flags ones with weak or aged values for owner attestation in Slack, and writes the review to a compliance table.',
    iconId: 'brand/infisical-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'infisical-6',
    blockType: 'infisical',
    label: 'Infisical secret-inventory snapshot',
    prompt:
        'Build a scheduled workflow that lists Infisical secrets across environments, writes a redacted inventory snapshot to S3 for long-term retention, and tracks secret count trends in a table.',
    iconId: 'brand/infisical-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'instantly-0',
    blockType: 'instantly',
    label: 'Instantly lead loader',
    prompt:
        'Build a workflow that reads new prospects from a table and creates each as a lead in the right Instantly campaign, then writes the Instantly lead ID back so the sender table stays in sync.',
    iconId: 'brand/instantly-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'instantly-1',
    blockType: 'instantly',
    label: 'Instantly reply triager',
    prompt:
        'Create a workflow triggered when an Instantly reply is received that classifies intent, updates the lead interest status, and posts a Slack alert for positive replies so reps follow up fast.',
    iconId: 'brand/instantly-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'instantly-2',
    blockType: 'instantly',
    label: 'Instantly campaign launcher',
    prompt:
        'Build a workflow that creates a new Instantly campaign from a brief, builds a lead list, loads the prospects, and activates the campaign once the list is ready.',
    iconId: 'brand/instantly-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'instantly-3',
    blockType: 'instantly',
    label: 'Instantly performance report',
    prompt:
        'Create a scheduled weekly workflow that lists Instantly campaigns and emails, computes reply and interest rates per campaign, logs them to a table for trend tracking, and Slacks a summary to the sales team.',
    iconId: 'brand/instantly-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'instantly-4',
    blockType: 'instantly',
    label: 'Instantly meeting-booked sync',
    prompt:
        'Build a workflow triggered when an Instantly lead is marked meeting booked that creates or updates the matching HubSpot contact and deal so the CRM reflects pipeline from outbound.',
    iconId: 'brand/instantly-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'instantly-5',
    blockType: 'instantly',
    label: 'Hunter + Instantly outbound',
    prompt:
        'Create a workflow that finds verified prospect emails with Hunter, validates each, and loads the deliverable contacts into an active Instantly campaign.',
    iconId: 'brand/instantly-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'instantly-6',
    blockType: 'instantly',
    label: 'Instantly reply router',
    prompt:
        'Build a scheduled workflow that lists new Instantly campaign email replies, classifies each as interested, objection, or out-of-office with an agent, updates the lead\'s interest status, and posts hot replies to the sales Slack channel for a fast follow-up.',
    iconId: 'brand/instantly-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'intercom-0',
    blockType: 'intercom',
    label: 'Intercom feedback analyzer',
    prompt:
        'Build a scheduled workflow that pulls support tickets and conversations from Intercom daily, categorizes them by theme and sentiment, tracks trends in a table, and sends a weekly Slack report highlighting the top feature requests and pain points.',
    iconId: 'brand/intercom-icon',
    modules: <String>['tables', 'scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'intercom-1',
    blockType: 'intercom',
    label: 'Intercom auto-resolver',
    prompt:
        'Create a knowledge base from my help center and product docs, then build a workflow that watches new Intercom conversations, attempts an answer with cited sources, and only assigns to a human admin when confidence is low or the customer asks.',
    iconId: 'brand/intercom-icon',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'intercom-2',
    blockType: 'intercom',
    label: 'Intercom to Linear bug ticketer',
    prompt:
        'Build a workflow triggered by new Intercom conversations that classifies whether the message is a bug report, extracts the repro steps and affected area, creates a Linear issue with the conversation transcript attached, and replies in Intercom with the issue ID.',
    iconId: 'brand/intercom-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'intercom-3',
    blockType: 'intercom',
    label: 'Intercom VIP escalation',
    prompt:
        'Create a workflow that monitors new Intercom conversations, looks up the contact in the CRM, and when the contact belongs to a top-tier account, snoozes the conversation, posts a Slack alert in #vip-support with full context, and tags the conversation as VIP.',
    iconId: 'brand/intercom-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'intercom-4',
    blockType: 'intercom',
    label: 'Intercom conversation summarizer',
    prompt:
        'Build a workflow triggered when an Intercom conversation is closed that summarizes the issue, resolution, and any follow-up actions, then appends the summary to a Notion knowledge log so the team can learn from past conversations.',
    iconId: 'brand/intercom-icon',
    modules: <String>['agent', 'workflows', 'knowledge-base'],
  ),
  SuggestionTemplate(
    id: 'intercom-5',
    blockType: 'intercom',
    label: 'Intercom contact enrichment',
    prompt:
        'Create a workflow triggered when a new Intercom contact is created that enriches the contact with company, title, and seniority data from Apollo, updates the Intercom contact attributes, and adds a note with the enrichment source.',
    iconId: 'brand/intercom-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'intercom-6',
    blockType: 'intercom',
    label: 'Intercom-Zendesk migration mirror',
    prompt:
        'Build a workflow that mirrors new Intercom conversations into Zendesk as tickets during a migration window, syncs status and replies in both directions, and writes a table of every mapped conversation-to-ticket pair for audit.',
    iconId: 'brand/intercom-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'intune-0',
    blockType: 'intune',
    label: 'Daily Compliance Review',
    prompt:
        'Build a scheduled agent that reads Intune managed devices and flags noncompliant devices with their owners and last check-in times. Publish a concise report with device IDs for follow-up.',
    iconId: 'brand/intune-icon',
    modules: <String>['scheduled', 'agent'],
    providerId: 'microsoft-intune',
  ),
  SuggestionTemplate(
    id: 'intune-1',
    blockType: 'intune',
    label: 'Software Inventory Audit',
    prompt:
        'Build an agent that pages through Intune detected apps, groups names and versions, and identifies installations of software on a supplied review list. Return affected application IDs and device counts.',
    iconId: 'brand/intune-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'microsoft-intune',
  ),
  SuggestionTemplate(
    id: 'intune-2',
    blockType: 'intune',
    label: 'Application Exposure Review',
    prompt:
        'When an application version is flagged for review, use Intune detected apps to identify its record and list the managed devices where it is installed. Produce the device names, owners, and compliance states.',
    iconId: 'brand/intune-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'microsoft-intune',
  ),
  SuggestionTemplate(
    id: 'intune-3',
    blockType: 'intune',
    label: 'Policy Deployment Triage',
    prompt:
        'Build an agent that reads a selected Intune compliance policy and its device statuses. Summarize compliant, noncompliant, conflicting, and error results with last report times.',
    iconId: 'brand/intune-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'microsoft-intune',
  ),
  SuggestionTemplate(
    id: 'intune-4',
    blockType: 'intune',
    label: 'Device Check-In Follow-Up',
    prompt:
        'Build a scheduled agent that finds Intune devices with stale check-in times and requests a sync for approved device IDs. Report accepted sync requests separately from later device check-ins.',
    iconId: 'brand/intune-icon',
    modules: <String>['scheduled', 'workflows'],
    providerId: 'microsoft-intune',
  ),
  SuggestionTemplate(
    id: 'intune-5',
    blockType: 'intune',
    label: 'Approved Device Retirement',
    prompt:
        'When an administrator approves a device retirement, read the Intune device and verify its ID and owner. Request retirement only with explicit confirmation and report that the request was accepted.',
    iconId: 'brand/intune-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'microsoft-intune',
  ),
  SuggestionTemplate(
    id: 'intune-6',
    blockType: 'intune',
    label: 'Help Desk Device Actions',
    prompt:
        'Build an agent that reads an Intune device during an IT support request, summarizes its operating system and compliance status, and requests a restart or remote lock only after an administrator explicitly confirms the action.',
    iconId: 'brand/intune-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'microsoft-intune',
  ),
  SuggestionTemplate(
    id: 'jina-0',
    blockType: 'jina',
    label: 'Jina URL-to-knowledge ingester',
    prompt:
        'Build a workflow that reads a list of source URLs with Jina Reader, converts each into clean text, and ingests the content into a research knowledge base for retrieval.',
    iconId: 'brand/jina-ai-icon',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'jina-1',
    blockType: 'jina',
    label: 'Jina web-research digest',
    prompt:
        'Create a scheduled workflow that runs Jina web search on tracked topics, reads the top results with Jina Reader, and writes a summarized digest to a research table.',
    iconId: 'brand/jina-ai-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'jina-2',
    blockType: 'jina',
    label: 'Jina web-content reader',
    prompt:
        'Build a workflow that uses Jina Reader to convert any URL into clean text, summarizes with an agent, and stores the result in a research knowledge base.',
    iconId: 'brand/jina-ai-icon',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'jina-3',
    blockType: 'jina',
    label: 'Jina competitor watch',
    prompt:
        'Create a scheduled workflow that reads competitor pricing and changelog pages with Jina Reader, diffs against the last snapshot, and posts notable changes to Slack.',
    iconId: 'brand/jina-ai-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'jina-4',
    blockType: 'jina',
    label: 'Jina answer enrichment',
    prompt:
        'Build a workflow that takes a user question, runs a Jina web search for current sources, reads the top pages with Jina Reader, and has an agent answer with citations.',
    iconId: 'brand/jina-ai-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'jina-5',
    blockType: 'jina',
    label: 'Jina Slack research bot',
    prompt:
        'Create a Slack bot that runs Jina web search on the asked question, reads the most relevant results with Jina Reader, and replies with a summarized answer and source links.',
    iconId: 'brand/jina-ai-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'jina-6',
    blockType: 'jina',
    label: 'Jina docs-to-Notion clipper',
    prompt:
        'Build a workflow that reads a submitted URL with Jina Reader, summarizes the content with an agent, and appends a clean clipped entry to a Notion research database.',
    iconId: 'brand/jina-ai-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'jira-0',
    blockType: 'jira',
    label: 'Jira knowledge search',
    prompt:
        'Create a knowledge base connected to my Jira project so all tickets, comments, and resolutions are automatically synced and searchable. Then build an agent I can ask things like "how did we fix the auth timeout issue?" or "what was decided about the API redesign?" and get answers with ticket citations.',
    iconId: 'brand/jira-icon',
    modules: <String>['knowledge-base', 'agent'],
    providerId: 'jira',
  ),
  SuggestionTemplate(
    id: 'jira-1',
    blockType: 'jira',
    label: 'Jira sprint report generator',
    prompt:
        'Create a scheduled workflow that runs at the end of each sprint, pulls all completed, in-progress, and blocked Jira tickets, calculates velocity and carry-over, and generates a sprint summary document with charts and trends to share with the team.',
    iconId: 'brand/jira-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
    providerId: 'jira',
  ),
  SuggestionTemplate(
    id: 'jira-2',
    blockType: 'jira',
    label: 'Jira backlog grooming digest',
    prompt:
        'Build a scheduled weekly workflow that scans Jira backlog for tickets missing estimates, owners, or priorities, generates a grooming queue, and posts the top items to Slack.',
    iconId: 'brand/jira-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'jira',
  ),
  SuggestionTemplate(
    id: 'jira-3',
    blockType: 'jira',
    label: 'Jira stale-ticket sweeper',
    prompt:
        'Create a scheduled workflow that lists Jira tickets with no activity in 14 days, pings the assignee in Slack with a status prompt, and updates the ticket based on the response.',
    iconId: 'brand/jira-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'jira',
  ),
  SuggestionTemplate(
    id: 'jira-4',
    blockType: 'jira',
    label: 'Jira release notes builder',
    prompt:
        'Build a workflow that pulls Jira tickets resolved since the last release tag, groups by feature area, and drafts user-facing release notes for marketing review.',
    iconId: 'brand/jira-icon',
    modules: <String>['agent', 'files', 'workflows'],
    providerId: 'jira',
  ),
  SuggestionTemplate(
    id: 'jira-5',
    blockType: 'jira',
    label: 'Jira to Linear migrator',
    prompt:
        'Create a workflow that imports a Jira project into Linear, preserving status mapping, labels, comments, and assignees, and writes a mapping table for redirect URLs.',
    iconId: 'brand/jira-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'jira',
  ),
  SuggestionTemplate(
    id: 'jira-6',
    blockType: 'jira',
    label: 'Auto-generate Confluence pages from Jira sprints',
    prompt:
        'Build a workflow that runs at the end of each Jira sprint, pulls all completed and in-progress tickets, and automatically creates a structured Confluence documentation page so sprint reporting requires no manual effort.',
    iconId: 'brand/jira-icon',
    modules: <String>['agent', 'workflows'],
    featured: true,
    providerId: 'jira',
  ),
  SuggestionTemplate(
    id: 'jira_service_management-0',
    blockType: 'jira_service_management',
    label: 'JSM major incident broadcaster',
    prompt:
        'Build a workflow triggered when a major-incident request is created in Jira Service Management that pulls the affected service from PagerDuty, identifies the current on-call, posts a structured incident brief to a Slack war-room channel, and adds the responders as JSM request participants.',
    iconId: 'brand/jira-service-management-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'jira',
  ),
  SuggestionTemplate(
    id: 'jira_service_management-1',
    blockType: 'jira_service_management',
    label: 'JSM request auto-triage',
    prompt:
        'Create a workflow triggered by new Jira Service Management requests that classifies the request type, sets the correct priority based on impact and urgency, transitions it to the right initial status, and adds the assignment-group customer organization as a participant.',
    iconId: 'brand/jira-service-management-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'jira',
  ),
  SuggestionTemplate(
    id: 'jira_service_management-2',
    blockType: 'jira_service_management',
    label: 'JSM approval router',
    prompt:
        'Build a workflow that watches Jira Service Management requests for new approval steps, posts a Slack DM to each approver with request context and quick-action buttons, and answers the approval in JSM based on their response while keeping the request in sync.',
    iconId: 'brand/jira-service-management-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'jira',
  ),
  SuggestionTemplate(
    id: 'jira_service_management-3',
    blockType: 'jira_service_management',
    label: 'JSM form auto-completer',
    prompt:
        'Create a workflow that when a Jira Service Management request is created with an attached ProForma form, pre-fills the answers from the requester profile, attached email, and CMDB lookup, and saves the answers so agents only review rather than retype.',
    iconId: 'brand/jira-service-management-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'jira',
  ),
  SuggestionTemplate(
    id: 'jira_service_management-4',
    blockType: 'jira_service_management',
    label: 'JSM weekly service desk report',
    prompt:
        'Build a scheduled weekly workflow that pulls Jira Service Management request volume by queue, SLA performance, top request types, and bottleneck assignees, and generates a service desk health report file for the operations review.',
    iconId: 'brand/jira-service-management-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
    providerId: 'jira',
  ),
  SuggestionTemplate(
    id: 'jira_service_management-5',
    blockType: 'jira_service_management',
    label: 'JSM-to-ServiceNow bridge',
    prompt:
        'Create a workflow that mirrors Jira Service Management incident requests into ServiceNow incident records and vice versa, keeping status, assignment, and comments in sync so teams on either side see the same truth.',
    iconId: 'brand/jira-service-management-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'jira',
  ),
  SuggestionTemplate(
    id: 'jira_service_management-6',
    blockType: 'jira_service_management',
    label: 'JSM self-service deflection bot',
    prompt:
        'Create a knowledge base from internal IT docs, then build a Slack agent that answers employee help requests with cited steps and, when it can\'t resolve the issue, creates a Jira Service Management request with the right request type so nothing falls through.',
    iconId: 'brand/jira-service-management-icon',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
    providerId: 'jira',
  ),
  SuggestionTemplate(
    id: 'jotform-0',
    blockType: 'jotform',
    label: 'Jotform submissions to a table',
    prompt:
        'Build a scheduled workflow that lists new Jotform submissions for a form every hour, filtering on submissions created since the last run, and appends each one to a table with the answers mapped to their question labels.',
    iconId: 'brand/jotform-icon',
    modules: <String>['tables', 'scheduled', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'jotform-1',
    blockType: 'jotform',
    label: 'Jotform lead routing to Slack',
    prompt:
        'Create a workflow that reads unread Jotform submissions for a contact form, has an agent classify each one as a sales lead, support request, or spam, and posts the qualified leads to the sales channel in Slack.',
    iconId: 'brand/jotform-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'jotform-2',
    blockType: 'jotform',
    label: 'Jotform applications into a hiring pipeline',
    prompt:
        'Build a workflow that pulls Jotform job application submissions, downloads the uploaded resume files from the form, has an agent summarize each candidate against the role requirements, and creates a Notion page per applicant.',
    iconId: 'brand/jotform-icon',
    modules: <String>['files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'jotform-3',
    blockType: 'jotform',
    label: 'Jotform submission webhook fan-out',
    prompt:
        'Create a workflow that registers a Jotform webhook on a form pointing at an API trigger, then processes each incoming submission by writing it to a table and emailing the submitter a confirmation.',
    iconId: 'brand/jotform-icon',
    modules: <String>['tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'jotform-4',
    blockType: 'jotform',
    label: 'Jotform support intake into tickets',
    prompt:
        'Build a workflow that reads new Jotform support form submissions, has an agent assign a priority and category from the answers, and opens a matching Linear issue with the submission details in the description.',
    iconId: 'brand/jotform-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'jotform-5',
    blockType: 'jotform',
    label: 'Jotform weekly response digest',
    prompt:
        'Create a scheduled workflow that runs every Monday, lists the past week of Jotform submissions across every form, has an agent summarize the themes and outliers, and emails the digest to the operations team.',
    iconId: 'brand/jotform-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'jotform-6',
    blockType: 'jotform',
    label: 'Jotform CRM sync for event signups',
    prompt:
        'Build a workflow that reads Jotform event registration submissions, upserts each attendee as a HubSpot contact with the answers mapped onto contact properties, and marks the submission as processed in a table.',
    iconId: 'brand/jotform-icon',
    modules: <String>['tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'jotform-7',
    blockType: 'jotform',
    label: 'Jotform report generation on demand',
    prompt:
        'Create a workflow that takes a form ID and a date range, creates a CSV Jotform report scoped to the selected question fields, and posts the shareable report link to the requesting Slack thread.',
    iconId: 'brand/jotform-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'jupyter-0',
    blockType: 'jupyter',
    label: 'Jupyter notebook creator',
    prompt:
        'Build a workflow that generates a Jupyter notebook from a data analysis request and creates it on a self-hosted Jupyter server.',
    iconId: 'brand/jupyter-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'jupyter-1',
    blockType: 'jupyter',
    label: 'Upload datasets to Jupyter',
    prompt:
        'Build a workflow that uploads a file from a Table row to a Jupyter server as a dataset for later analysis.',
    iconId: 'brand/jupyter-icon',
    modules: <String>['tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'jupyter-2',
    blockType: 'jupyter',
    label: 'Jupyter kernel health check',
    prompt:
        'Build a scheduled workflow that lists running Jupyter kernels, restarts any kernel stuck in a busy state, and posts a summary to Slack.',
    iconId: 'brand/jupyter-icon',
    modules: <String>['scheduled', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'jupyter-3',
    blockType: 'jupyter',
    label: 'Jupyter directory sync report',
    prompt:
        'Build a workflow that lists the contents of a Jupyter server directory and writes a summary of files and notebooks to a Table.',
    iconId: 'brand/jupyter-icon',
    modules: <String>['tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'jupyter-4',
    blockType: 'jupyter',
    label: 'Summarize a Jupyter notebook',
    prompt:
        'Build a workflow that reads a Jupyter notebook, has an agent summarize its cells, and sends the summary in Chat.',
    iconId: 'brand/jupyter-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'jupyter-5',
    blockType: 'jupyter',
    label: 'Provision a Jupyter session',
    prompt:
        'Build a workflow that creates a Jupyter session bound to a new notebook and a fresh Python kernel whenever a new project request comes in.',
    iconId: 'brand/jupyter-icon',
    modules: <String>['workflows'],
  ),
  SuggestionTemplate(
    id: 'jupyter-6',
    blockType: 'jupyter',
    label: 'Archive Jupyter notebooks',
    prompt:
        'Build a scheduled workflow that copies old notebooks on a Jupyter server into an archive directory, then deletes the originals.',
    iconId: 'brand/jupyter-icon',
    modules: <String>['scheduled', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'jupyter_v2-0',
    blockType: 'jupyter_v2',
    label: 'Jupyter notebook creator',
    prompt:
        'Build a workflow that generates a Jupyter notebook from a data analysis request and creates it on a self-hosted Jupyter server.',
    iconId: 'brand/jupyter-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'jupyter_v2-1',
    blockType: 'jupyter_v2',
    label: 'Upload datasets to Jupyter',
    prompt:
        'Build a workflow that uploads a file from a Table row to a Jupyter server as a dataset for later analysis.',
    iconId: 'brand/jupyter-icon',
    modules: <String>['tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'jupyter_v2-2',
    blockType: 'jupyter_v2',
    label: 'Jupyter kernel health check',
    prompt:
        'Build a scheduled workflow that lists running Jupyter kernels, restarts any kernel stuck in a busy state, and posts a summary to Slack.',
    iconId: 'brand/jupyter-icon',
    modules: <String>['scheduled', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'jupyter_v2-3',
    blockType: 'jupyter_v2',
    label: 'Jupyter directory sync report',
    prompt:
        'Build a workflow that lists the contents of a Jupyter server directory and writes a summary of files and notebooks to a Table.',
    iconId: 'brand/jupyter-icon',
    modules: <String>['tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'jupyter_v2-4',
    blockType: 'jupyter_v2',
    label: 'Summarize a Jupyter notebook',
    prompt:
        'Build a workflow that reads a Jupyter notebook, has an agent summarize its cells, and sends the summary in Chat.',
    iconId: 'brand/jupyter-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'jupyter_v2-5',
    blockType: 'jupyter_v2',
    label: 'Provision a Jupyter session',
    prompt:
        'Build a workflow that creates a Jupyter session bound to a new notebook and a fresh Python kernel whenever a new project request comes in.',
    iconId: 'brand/jupyter-icon',
    modules: <String>['workflows'],
  ),
  SuggestionTemplate(
    id: 'jupyter_v2-6',
    blockType: 'jupyter_v2',
    label: 'Archive Jupyter notebooks',
    prompt:
        'Build a scheduled workflow that copies old notebooks on a Jupyter server into an archive directory, then deletes the originals.',
    iconId: 'brand/jupyter-icon',
    modules: <String>['scheduled', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'kalshi-0',
    blockType: 'kalshi',
    label: 'Kalshi event-contract tracker',
    prompt:
        'Create a scheduled workflow that polls Kalshi for prices on tracked event contracts, writes the price history to a tables-based portfolio, and posts large-move alerts to Slack.',
    iconId: 'brand/kalshi-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'kalshi-1',
    blockType: 'kalshi',
    label: 'Kalshi macroeconomic dashboard',
    prompt:
        'Build a scheduled workflow that pulls Kalshi probability markets for selected macroeconomic events, writes the implied probabilities to a tables-based dashboard, and emails a weekly summary.',
    iconId: 'brand/kalshi-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'kalshi-2',
    blockType: 'kalshi',
    label: 'Kalshi + Polymarket arbitrage scanner',
    prompt:
        'Create a scheduled workflow that fetches comparable contracts on Kalshi and Polymarket, computes implied-probability spreads, writes the top arbitrage candidates to a table, and pings Slack on significant gaps.',
    iconId: 'brand/kalshi-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'kalshi-3',
    blockType: 'kalshi',
    label: 'Kalshi + Profound macro signal',
    prompt:
        'Build a scheduled workflow that combines Kalshi event-contract prices with Profound AI signal to forecast macro events and writes a thesis file weekly.',
    iconId: 'brand/kalshi-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'kalshi-4',
    blockType: 'kalshi',
    label: 'Kalshi position rebalancer',
    prompt:
        'Build a workflow that monitors Kalshi position weights against a target allocation, captures drift, and pings Slack with proposed rebalancing trades.',
    iconId: 'brand/kalshi-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'kalshi-5',
    blockType: 'kalshi',
    label: 'Kalshi earnings event tracker',
    prompt:
        'Create a workflow that pulls Kalshi earnings-event contracts, captures implied probabilities the day before each event, and writes a per-ticker table for review.',
    iconId: 'brand/kalshi-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'kalshi-6',
    blockType: 'kalshi',
    label: 'Kalshi election-market dashboard',
    prompt:
        'Build a scheduled workflow that pulls Kalshi election market prices, captures movement over time, and writes a per-race tracking table for political analysts.',
    iconId: 'brand/kalshi-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ketch-0',
    blockType: 'ketch',
    label: 'Ketch consent propagator',
    prompt:
        'Build a workflow that on a consent change reads the contact’s Ketch consent state and propagates it to downstream systems — HubSpot and Loops — keeping privacy preferences in sync.',
    iconId: 'brand/ketch-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ketch-1',
    blockType: 'ketch',
    label: 'Ketch DSR fulfillment',
    prompt:
        'Create a workflow that on a Ketch data subject request collects matching personal data from connected systems, generates the export, and writes the fulfillment audit.',
    iconId: 'brand/ketch-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ketch-2',
    blockType: 'ketch',
    label: 'Ketch deletion-request handler',
    prompt:
        'Build a workflow that on a Ketch deletion request propagates the deletion to all connected systems, captures confirmations, and writes the chain of custody.',
    iconId: 'brand/ketch-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ketch-3',
    blockType: 'ketch',
    label: 'Ketch consent-drift detector',
    prompt:
        'Create a scheduled workflow that compares Ketch consent state with downstream systems, flags drift, and writes a remediation queue for the privacy team.',
    iconId: 'brand/ketch-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ketch-4',
    blockType: 'ketch',
    label: 'Ketch subscription sync',
    prompt:
        'Build a workflow that reads each contact’s Ketch subscription topics and mirrors the opt-in state to the marketing tool so unsubscribe preferences stay consistent across systems.',
    iconId: 'brand/ketch-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ketch-5',
    blockType: 'ketch',
    label: 'Ketch right-invocation handler',
    prompt:
        'Create a workflow that on an incoming privacy request invokes the matching Ketch right for the data subject, captures the confirmation, and writes the action to a compliance file.',
    iconId: 'brand/ketch-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ketch-6',
    blockType: 'ketch',
    label: 'Ketch consent-rate digest',
    prompt:
        'Build a scheduled monthly workflow that samples Ketch consent state across a contact list, computes opt-in rates per purpose, and writes a privacy report file for executive review.',
    iconId: 'brand/ketch-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'lambda-0',
    blockType: 'lambda',
    label: 'Lambda function runner',
    prompt:
        'Create a workflow that takes a JSON request as input, invokes an AWS Lambda function with it, parses the returned payload, and posts the result to Slack. If the invocation returns a function error, include the decoded execution log tail in the alert.',
    iconId: 'brand/lambda-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'lambda-1',
    blockType: 'lambda',
    label: 'Lambda function inventory',
    prompt:
        'Build a scheduled weekly workflow that lists every AWS Lambda function in the account, captures runtime, memory, timeout, last modified date, and architecture, and writes the inventory into a tracking table so the platform team can spot deprecated runtimes.',
    iconId: 'brand/lambda-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'lambda-2',
    blockType: 'lambda',
    label: 'Lambda deprecated runtime sweep',
    prompt:
        'Create a scheduled monthly workflow that lists all Lambda functions, flags any running a deprecated runtime, groups them by owning team using function tags, and opens a Linear ticket per team with the list of functions that need upgrading.',
    iconId: 'brand/lambda-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'lambda-3',
    blockType: 'lambda',
    label: 'Lambda blue-green release',
    prompt:
        'Build a workflow that updates a Lambda function from a new S3 deployment package, publishes a version, shifts 10 percent of alias traffic to it with weighted routing, waits for approval in Slack, then promotes the alias to 100 percent or rolls it back.',
    iconId: 'brand/lambda-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'lambda-4',
    blockType: 'lambda',
    label: 'Lambda concurrency guard',
    prompt:
        'Create a scheduled workflow that reads Lambda account settings and each function reserved concurrency, detects when unreserved concurrency drops below a safe floor, and alerts the on-call channel with the functions consuming the most reserved capacity.',
    iconId: 'brand/lambda-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'lambda-5',
    blockType: 'lambda',
    label: 'Lambda event source auditor',
    prompt:
        'Build a scheduled workflow that lists every Lambda event source mapping, flags any whose state is not Enabled or whose last processing result reports errors, summarizes the likely cause, and posts a daily digest to Slack.',
    iconId: 'brand/lambda-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'lambda-6',
    blockType: 'lambda',
    label: 'Lambda permission reviewer',
    prompt:
        'Create a scheduled workflow that reads the resource-based policy of every Lambda function, flags statements that grant access to a wildcard principal or an account outside your organization, and writes a written findings report for the security team.',
    iconId: 'brand/lambda-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'lambda-7',
    blockType: 'lambda',
    label: 'Lambda public URL detector',
    prompt:
        'Build a scheduled workflow that lists Lambda function URL configurations across your functions, flags any whose auth type is NONE or whose CORS allows any origin, and opens a Linear ticket for each exposed endpoint.',
    iconId: 'brand/lambda-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'lambda-8',
    blockType: 'lambda',
    label: 'Lambda async failure triage',
    prompt:
        'Create a workflow that reads the asynchronous invocation configuration of a Lambda function, pulls failed invocation records from its on-failure destination queue, invokes the function again in dry run mode to check permissions, and summarizes the failure cause in Slack.',
    iconId: 'brand/lambda-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'langsmith-0',
    blockType: 'langsmith',
    label: 'LangSmith agent-run tracer',
    prompt:
        'Build a workflow that wraps an agent step and forwards each run to LangSmith with inputs, outputs, and latency so the ML team can trace executions in one project.',
    iconId: 'brand/langsmith-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'langsmith-1',
    blockType: 'langsmith',
    label: 'LangSmith error logger',
    prompt:
        'Create a workflow that on a failed agent step forwards a LangSmith run tagged as an error with the inputs and error message, and posts the run link to Slack for the ML team.',
    iconId: 'brand/langsmith-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'langsmith-2',
    blockType: 'langsmith',
    label: 'LangSmith feedback capture',
    prompt:
        'Build a workflow that collects user-reported agent failures from a table and attaches each as scored LangSmith feedback on the originating run for later review.',
    iconId: 'brand/langsmith-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'langsmith-3',
    blockType: 'langsmith',
    label: 'LangSmith run completion',
    prompt:
        'Build a workflow that creates a LangSmith run when an agent step starts, then updates it with outputs, status, and end time once the step finishes so traces always show the full lifecycle.',
    iconId: 'brand/langsmith-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'langsmith-4',
    blockType: 'langsmith',
    label: 'LangSmith batch run shipper',
    prompt:
        'Create a scheduled workflow that reads completed agent runs from a table and posts them to LangSmith in a single batch so observability stays in sync without per-run overhead.',
    iconId: 'brand/langsmith-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'langsmith-5',
    blockType: 'langsmith',
    label: 'LangSmith session tagger',
    prompt:
        'Build a workflow that forwards each agent run to LangSmith tagged with the originating feature and environment so traces can be filtered by surface in the LangSmith project.',
    iconId: 'brand/langsmith-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'langsmith-6',
    blockType: 'langsmith',
    label: 'LangSmith RAG step logger',
    prompt:
        'Create a workflow that runs a retrieval-augmented agent and forwards a LangSmith run per step — retriever, prompt, and llm — so the ML team can inspect each stage of the chain.',
    iconId: 'brand/langsmith-icon',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'langsmith-7',
    blockType: 'langsmith',
    label: 'LangSmith multi-agent tracer',
    prompt:
        'Build a workflow that forwards a LangSmith run for each agent in a multi-step pipeline under one trace, so the full conversation is visible end-to-end in LangSmith.',
    iconId: 'brand/langsmith-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'latex-0',
    blockType: 'latex',
    label: 'LaTeX invoice generator',
    prompt:
        'Build a workflow that takes invoice line items from a table, fills a LaTeX invoice template, compiles it to PDF, and emails the invoice to the customer.',
    iconId: 'brand/latex-icon',
    modules: <String>['tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'latex-1',
    blockType: 'latex',
    label: 'LaTeX research report writer',
    prompt:
        'Create a workflow where an agent researches a topic from the knowledge base, writes the findings as a LaTeX article, and compiles a polished PDF report.',
    iconId: 'brand/latex-icon',
    modules: <String>['agent', 'knowledge-base', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'latex-2',
    blockType: 'latex',
    label: 'LaTeX weekly metrics report',
    prompt:
        'Build a scheduled weekly workflow that pulls metrics from a table, typesets a LaTeX report with charts and tables, compiles it to PDF, and posts it to Slack.',
    iconId: 'brand/latex-icon',
    modules: <String>['scheduled', 'tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'latex-3',
    blockType: 'latex',
    label: 'LaTeX offer letter generator',
    prompt:
        'Create a workflow that takes candidate details from a form, fills a LaTeX offer letter template, compiles it to PDF, and sends it for e-signature.',
    iconId: 'brand/latex-icon',
    modules: <String>['workflows'],
  ),
  SuggestionTemplate(
    id: 'latex-4',
    blockType: 'latex',
    label: 'LaTeX math worksheet builder',
    prompt:
        'Build a workflow where an agent generates practice problems for a given math topic and difficulty, typesets them with LaTeX equations, and compiles a printable worksheet PDF.',
    iconId: 'brand/latex-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'latex-5',
    blockType: 'latex',
    label: 'LaTeX proposal generator',
    prompt:
        'Create a workflow that pulls deal details from HubSpot, has an agent draft a tailored proposal in LaTeX, compiles it to PDF, and saves it to the deal record.',
    iconId: 'brand/latex-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'latex-6',
    blockType: 'latex',
    label: 'LaTeX paper digest compiler',
    prompt:
        'Build a scheduled workflow that fetches new ArXiv papers on tracked topics, has an agent summarize each one, typesets the digest as a LaTeX document, and compiles a weekly PDF.',
    iconId: 'brand/latex-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'latex-7',
    blockType: 'latex',
    label: 'LaTeX certificate generator',
    prompt:
        'Create a workflow that reads attendee names from a spreadsheet, fills a LaTeX certificate template for each attendee, compiles the PDFs, and emails each certificate to its recipient.',
    iconId: 'brand/latex-icon',
    modules: <String>['workflows'],
  ),
  SuggestionTemplate(
    id: 'launchdarkly-0',
    blockType: 'launchdarkly',
    label: 'LaunchDarkly flag-flip auditor',
    prompt:
        'Build a scheduled workflow that reads the LaunchDarkly audit log, captures who flipped which flag and when, and writes the audit trail to a tracking table with diff context.',
    iconId: 'brand/launch-darkly-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'launchdarkly-1',
    blockType: 'launchdarkly',
    label: 'LaunchDarkly stale-flag sweeper',
    prompt:
        'Create a scheduled workflow that identifies LaunchDarkly flags inactive for 60 days, opens Linear tickets to remove them, and writes the cleanup queue to a dashboard table.',
    iconId: 'brand/launch-darkly-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'launchdarkly-2',
    blockType: 'launchdarkly',
    label: 'LaunchDarkly rollout digest',
    prompt:
        'Build a scheduled weekly workflow that lists LaunchDarkly flags with their current status and rollout percentage per environment, summarizes what changed since last week, and posts a digest to the product Slack channel.',
    iconId: 'brand/launch-darkly-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'launchdarkly-3',
    blockType: 'launchdarkly',
    label: 'LaunchDarkly flag-flip safety gate',
    prompt:
        'Create a scheduled workflow that reads the LaunchDarkly audit log for recent production flag flips, checks Sentry error rate and Datadog SLO burn against each, toggles the flag back off on regression, and posts to Slack.',
    iconId: 'brand/launch-darkly-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'launchdarkly-4',
    blockType: 'launchdarkly',
    label: 'LaunchDarkly targeted rollout assistant',
    prompt:
        'Build a workflow that takes a LaunchDarkly flag and a rollout plan, advances the rollout percentage on a schedule while watching health metrics, pausing on degradation.',
    iconId: 'brand/launch-darkly-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'launchdarkly-5',
    blockType: 'launchdarkly',
    label: 'LaunchDarkly + Linear release planner',
    prompt:
        'Create a workflow that watches Linear releases marked behind a LaunchDarkly flag, validates the flag exists, posts the rollout plan to Slack, and tracks rollout progress on the release ticket.',
    iconId: 'brand/launch-darkly-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'launchdarkly-6',
    blockType: 'launchdarkly',
    label: 'LaunchDarkly customer-segment toggler',
    prompt:
        'Build a workflow that turns a HubSpot segment into a LaunchDarkly targeting rule, keeping the rule in sync with the segment, and writes the sync log to a tracking table.',
    iconId: 'brand/launch-darkly-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'lemlist-0',
    blockType: 'lemlist',
    label: 'Lemlist reply router',
    prompt:
        'Create a workflow triggered by Lemlist reply webhooks that classifies each reply by intent and posts a Slack notification to the lead owner with a one-line summary, the intent, and the reply text.',
    iconId: 'brand/lemlist-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'lemlist-1',
    blockType: 'lemlist',
    label: 'Lemlist campaign analyzer',
    prompt:
        'Build a scheduled workflow that pulls Lemlist campaign activities, computes open, click, reply, and bounce rates per campaign and per step, and writes the results to a tracking table so I can spot the steps that need rewriting.',
    iconId: 'brand/lemlist-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'lemlist-2',
    blockType: 'lemlist',
    label: 'Lemlist + Apollo prospect feeder',
    prompt:
        'Create a workflow that runs an Apollo search for an ICP, enriches each prospect with role and company signals, and sends a personalized first-touch email through Lemlist with a custom opening line per prospect.',
    iconId: 'brand/lemlist-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'lemlist-3',
    blockType: 'lemlist',
    label: 'Lemlist interested-lead booker',
    prompt:
        'Build a workflow triggered when a Lemlist lead is marked interested that drafts a Calendly link tailored to the lead, replies to them through Lemlist with the link, and creates a follow-up task for the rep.',
    iconId: 'brand/lemlist-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'lemlist-4',
    blockType: 'lemlist',
    label: 'Lemlist activity dashboard',
    prompt:
        'Create a scheduled daily workflow that pulls Lemlist activity for the last 24 hours, summarizes opens, clicks, replies, and step performance per campaign, and writes a per-rep dashboard to a table.',
    iconId: 'brand/lemlist-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'lemlist-5',
    blockType: 'lemlist',
    label: 'Lemlist bounced lead sweeper',
    prompt:
        'Build a workflow triggered by Lemlist email-bounced events that looks up the lead, writes the bounce to a suppression table, and posts a Slack alert so the team can clean the list and keep quality high.',
    iconId: 'brand/lemlist-icon',
    modules: <String>['agent', 'tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'lemlist-6',
    blockType: 'lemlist',
    label: 'Lemlist to HubSpot logger',
    prompt:
        'Create a workflow that watches Lemlist activity and logs every send, open, click, and reply to the matching HubSpot contact as an engagement, and creates a HubSpot task for the rep on positive replies.',
    iconId: 'brand/lemlist-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'linear-0',
    blockType: 'linear',
    label: 'Linear knowledge search',
    prompt:
        'Create a knowledge base connected to my Linear workspace so all issues, comments, project updates, and decisions are automatically synced and searchable. Then build an agent I can ask things like "why did we deprioritize the mobile app?" or "what was the root cause of the checkout bug?" and get answers traced back to specific issues.',
    iconId: 'brand/linear-icon',
    modules: <String>['knowledge-base', 'agent'],
    providerId: 'linear',
  ),
  SuggestionTemplate(
    id: 'linear-1',
    blockType: 'linear',
    label: 'Linear ticket to Devin pipeline',
    prompt:
        'Create a workflow that fires when a Linear ticket gets the "devin" label, transforms the ticket description, acceptance criteria, and linked context into a Devin prompt, creates a session, and posts the session link plus an estimated completion window back on the ticket.',
    iconId: 'brand/devin-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'linear',
  ),
  SuggestionTemplate(
    id: 'linear-2',
    blockType: 'linear',
    label: 'Meeting notes to Linear tasks',
    prompt:
        'Create a workflow that takes meeting notes or a transcript, extracts action items with owners and due dates, creates tasks in Linear or Asana for each one, and posts a summary to the relevant Slack channel.',
    iconId: 'brand/linear-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'linear',
  ),
  SuggestionTemplate(
    id: 'linear-3',
    blockType: 'linear',
    label: 'Linear issue updates in Slack',
    prompt:
        'Build a workflow that monitors Linear for new issues, assignments, and completions, and posts a formatted Slack message for each event so your team is always in the loop.',
    iconId: 'brand/linear-icon',
    modules: <String>['agent', 'workflows'],
    featured: true,
    providerId: 'linear',
  ),
  SuggestionTemplate(
    id: 'linear-4',
    blockType: 'linear',
    label: 'Bug report to Linear issue',
    prompt:
        'Build a workflow that watches a Slack channel for bug reports, extracts the steps to reproduce and severity with an agent, creates a labeled Linear issue in the right team, and replies in-thread with the issue link.',
    iconId: 'brand/linear-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'linear',
  ),
  SuggestionTemplate(
    id: 'linear-5',
    blockType: 'linear',
    label: 'Linear triage labeler',
    prompt:
        'Create a workflow that on a newly created Linear issue reads the title and description, adds the right labels for type and priority, assigns it to the correct team based on the area, and comments a triage summary.',
    iconId: 'brand/linear-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'linear',
  ),
  SuggestionTemplate(
    id: 'linear-6',
    blockType: 'linear',
    label: 'Linear sprint review digest',
    prompt:
        'Build a scheduled weekly workflow that searches Linear for issues completed and still open in the active cycle, summarizes progress and blockers with an agent, logs velocity to a table, and posts a sprint review digest to Slack.',
    iconId: 'brand/linear-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'linear',
  ),
  SuggestionTemplate(
    id: 'linkedin-0',
    blockType: 'linkedin',
    label: 'LinkedIn content engine',
    prompt:
        'Build a workflow that scrapes my company blog for new posts, generates LinkedIn posts with hooks, insights, and calls-to-action optimized for engagement, and saves drafts as files for my review before posting to LinkedIn.',
    iconId: 'brand/linked-in-icon',
    modules: <String>['agent', 'files', 'scheduled', 'workflows'],
    providerId: 'linkedin',
  ),
  SuggestionTemplate(
    id: 'linkedin-1',
    blockType: 'linkedin',
    label: 'LinkedIn news-to-post writer',
    prompt:
        'Build a scheduled workflow that searches the web for news in my industry, drafts a short take with a hook and a call-to-action for each top story, and shares the best one to my LinkedIn feed.',
    iconId: 'brand/linked-in-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'linkedin',
  ),
  SuggestionTemplate(
    id: 'linkedin-2',
    blockType: 'linkedin',
    label: 'LinkedIn launch announcer',
    prompt:
        'Create a workflow that on a launch trigger from a table drafts a LinkedIn announcement post with the key details and a link, shares it to my LinkedIn feed, and marks the row as posted.',
    iconId: 'brand/linked-in-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'linkedin',
  ),
  SuggestionTemplate(
    id: 'linkedin-3',
    blockType: 'linkedin',
    label: 'LinkedIn weekly recap poster',
    prompt:
        'Build a scheduled weekly workflow that summarizes the week’s wins from a table, drafts a recap post with an agent, and shares it to my LinkedIn feed.',
    iconId: 'brand/linked-in-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'linkedin',
  ),
  SuggestionTemplate(
    id: 'linkedin-4',
    blockType: 'linkedin',
    label: 'LinkedIn content scheduler',
    prompt:
        'Create a workflow that reads a tables-based LinkedIn content calendar, posts each entry at the scheduled time, and writes the post URL back to the row.',
    iconId: 'brand/linked-in-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'linkedin',
  ),
  SuggestionTemplate(
    id: 'linkedin-5',
    blockType: 'linkedin',
    label: 'Blog-to-LinkedIn repurposer',
    prompt:
        'Build a workflow that on a newly published blog post drafts a punchy LinkedIn post summarizing the key insight with an agent, shares it to my LinkedIn profile, and logs the post URL to a content table for tracking.',
    iconId: 'brand/linked-in-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'linkedin',
  ),
  SuggestionTemplate(
    id: 'linkedin-6',
    blockType: 'linkedin',
    label: 'LinkedIn thought-leadership cadence',
    prompt:
        'Create a scheduled workflow that picks the next idea from a content table, expands it into a full LinkedIn post with an agent, shares it to my LinkedIn feed, and logs the publish time back to the row.',
    iconId: 'brand/linked-in-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'linkedin',
  ),
  SuggestionTemplate(
    id: 'linkup-0',
    blockType: 'linkup',
    label: 'Linkup research agent',
    prompt:
        'Build a research agent that uses Linkup to find authoritative sources on a topic, returns answers with citations, and saves long-form research to a knowledge base.',
    iconId: 'brand/linkup-icon',
    modules: <String>['agent', 'knowledge-base', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'linkup-1',
    blockType: 'linkup',
    label: 'Linkup daily digest',
    prompt:
        'Create a scheduled daily workflow that runs Linkup searches on tracked topics, summarizes the top hits with citations, and emails the user a research digest.',
    iconId: 'brand/linkup-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'linkup-2',
    blockType: 'linkup',
    label: 'Linkup competitor monitor',
    prompt:
        'Build a scheduled workflow that runs Linkup searches for competitor mentions weekly, scores each by relevance, and writes a log to a tables-based competitive intel base.',
    iconId: 'brand/linkup-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'linkup-3',
    blockType: 'linkup',
    label: 'Linkup CRM account refresh',
    prompt:
        'Create a scheduled workflow that for accounts in the CRM runs Linkup research on each weekly, surfaces new signals, and writes the digest into the account record.',
    iconId: 'brand/linkup-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'linkup-4',
    blockType: 'linkup',
    label: 'Linkup + Slack research bot',
    prompt:
        'Build a Slack bot that answers research questions with Linkup-grounded citations, hands off to a human on low-confidence answers, and logs each conversation.',
    iconId: 'brand/linkup-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'linkup-5',
    blockType: 'linkup',
    label: 'Linkup deep-research file',
    prompt:
        'Create a workflow that for a chosen topic runs Linkup deep research, captures the structured findings, and writes a full report file with citations.',
    iconId: 'brand/linkup-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'linkup-6',
    blockType: 'linkup',
    label: 'Linkup pipeline-research feeder',
    prompt:
        'Build a workflow that takes a list of accounts in a research table, runs Linkup on each for the latest news, and writes findings back to the row.',
    iconId: 'brand/linkup-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'linq-0',
    blockType: 'linq',
    label: 'Linq iMessage campaign sender',
    prompt:
        'Build a workflow that reads a contact list from a table, composes a personalized iMessage for each recipient using an agent, and sends them via Linq in batches.',
    iconId: 'brand/linq-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'linq-1',
    blockType: 'linq',
    label: 'Linq SMS support responder',
    prompt:
        'Create a scheduled workflow that lists recent unread Linq messages, generates a reply for each with an agent, and sends the response back to the same chat.',
    iconId: 'brand/linq-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'linq-2',
    blockType: 'linq',
    label: 'Linq RCS notification dispatcher',
    prompt:
        'Build a workflow that monitors a table for new alert rows, formats an RCS notification for each, and dispatches it to the relevant phone number via Linq.',
    iconId: 'brand/linq-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'logfire-0',
    blockType: 'logfire',
    label: 'Logfire error digest',
    prompt:
        'Create a scheduled workflow that runs every morning, searches Logfire for records at error level or above from the last 24 hours, groups them by service and exception type, and posts a ranked digest to Slack with the worst offenders first.',
    iconId: 'brand/logfire-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'logfire-1',
    blockType: 'logfire',
    label: 'Logfire trace investigator',
    prompt:
        'Build a workflow that takes a Logfire trace ID, fetches every span in the trace, walks the parent-child tree to find the slowest span and the first exception, and writes a plain-English root-cause summary back as a Linear comment.',
    iconId: 'emcn/search',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'logfire-2',
    blockType: 'logfire',
    label: 'Logfire latency watchdog',
    prompt:
        'Create a workflow that runs every 15 minutes, uses SQL against the Logfire records table to compute p95 duration per span_name over the window, compares it against the prior window stored in a table, and pages on-call through PagerDuty when latency regresses more than 50 percent.',
    iconId: 'emcn/clock',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'logfire-3',
    blockType: 'logfire',
    label: 'Logfire LLM cost tracker',
    prompt:
        'Build a scheduled daily workflow that queries Logfire for spans emitted by LLM instrumentation, extracts token counts from the attributes JSON, aggregates spend per model and per service into a table, and emails finance when a service trends over budget.',
    iconId: 'emcn/clipboard-list',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'logfire-4',
    blockType: 'logfire',
    label: 'Logfire release regression check',
    prompt:
        'Create a workflow that fires after each deploy, waits for a soak period, then searches Logfire for new exception types in the production environment that were not present before the release, and comments the diff on the GitHub pull request that shipped it.',
    iconId: 'emcn/bug',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'logfire-5',
    blockType: 'logfire',
    label: 'Logfire customer issue triage',
    prompt:
        'Build a workflow triggered by a support ticket that pulls the customer request ID from the ticket, searches Logfire for records matching that ID, fetches the full trace when one is found, and replies in Zendesk with whether the failure was user error or a backend fault.',
    iconId: 'emcn/server',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'logfire-6',
    blockType: 'logfire',
    label: 'Logfire weekly reliability review',
    prompt:
        'Create a scheduled weekly workflow that runs SQL against Logfire for error rate, throughput, and duration percentiles per service, writes a narrative reliability review file for the SRE team, and highlights every service whose error budget burn accelerated week over week.',
    iconId: 'emcn/file',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'logfire-7',
    blockType: 'logfire',
    label: 'Logfire agent run auditor',
    prompt:
        'Build a workflow that searches Logfire for spans from your AI agent service where an exception was recorded, fetches each full trace to capture the prompt and tool calls that led to the failure, and logs a structured failure catalog to a table for prompt tuning.',
    iconId: 'emcn/database',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'logrocket-0',
    blockType: 'logrocket',
    label: 'LogRocket session triage from support tickets',
    prompt:
        'Build a workflow that triggers on a new Zendesk ticket, requests LogRocket session highlights for the reporting user, polls until the result is ready, and posts the session summary back onto the ticket as an internal note.',
    iconId: 'brand/log-rocket-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'logrocket-1',
    blockType: 'logrocket',
    label: 'LogRocket churn-risk session review',
    prompt:
        'Create a scheduled workflow that reads at-risk accounts from a table, requests LogRocket session highlights for each contact, and writes the summarized friction points back to the table for the customer success team.',
    iconId: 'brand/log-rocket-icon',
    modules: <String>['tables', 'scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'logrocket-2',
    blockType: 'logrocket',
    label: 'LogRocket bug report enrichment',
    prompt:
        'Build a workflow that triggers on a new Linear bug issue, asks LogRocket for session highlights of the affected user with the bug description as the question, and comments the session breakdown on the issue.',
    iconId: 'brand/log-rocket-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'logrocket-3',
    blockType: 'logrocket',
    label: 'LogRocket audit log compliance export',
    prompt:
        'Create a scheduled workflow that pages through the LogRocket audit log every night, writes each entry to a compliance table, and alerts Slack when a session was viewed by someone outside the approved reviewer list.',
    iconId: 'brand/log-rocket-icon',
    modules: <String>['tables', 'scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'logrocket-4',
    blockType: 'logrocket',
    label: 'LogRocket session export pipeline',
    prompt:
        'Build a scheduled workflow that lists newly exported LogRocket session files, downloads each JSON Lines export, and loads the parsed events into a warehouse table for analysis.',
    iconId: 'brand/log-rocket-icon',
    modules: <String>['tables', 'scheduled', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'logrocket-5',
    blockType: 'logrocket',
    label: 'LogRocket profile sync from CRM',
    prompt:
        'Create a workflow that watches HubSpot contact updates and pushes the plan, lifecycle stage, and account value into LogRocket as user traits so sessions can be filtered by customer segment.',
    iconId: 'brand/log-rocket-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'logrocket-6',
    blockType: 'logrocket',
    label: 'LogRocket + Sentry incident context',
    prompt:
        'Build a workflow that triggers on a new Sentry issue, requests LogRocket session highlights for the impacted user, and posts a combined stack trace plus session narrative into the incident Slack channel.',
    iconId: 'brand/log-rocket-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'logrocket-7',
    blockType: 'logrocket',
    label: 'LogRocket release tagging on deploy',
    prompt:
        'Build a workflow that runs after a GitHub deployment succeeds, registers the deployed version as a LogRocket release so stack traces decode against it, and posts the tagged version to the release channel in Slack.',
    iconId: 'brand/log-rocket-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'loops-0',
    blockType: 'loops',
    label: 'Loops product event tracker',
    prompt:
        'Build a workflow that listens for product events from my tables, sends matching Loops events for each user with structured properties, and updates contact properties so Loops automations can branch on real product behavior.',
    iconId: 'brand/loops-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'loops-1',
    blockType: 'loops',
    label: 'Loops list hygiene',
    prompt:
        'Create a scheduled workflow that reads a Sim table of user activity to find accounts inactive for 90 days, updates each contact in Loops to the dormant user group and unsubscribes them from non-essential mailing lists, and writes a hygiene report to a table.',
    iconId: 'brand/loops-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'loops-2',
    blockType: 'loops',
    label: 'Loops onboarding orchestrator',
    prompt:
        'Build a workflow triggered on signup that creates a Loops contact, kicks off the onboarding event sequence, and updates user group as the user completes activation steps so the right Loops email goes out at every milestone.',
    iconId: 'brand/loops-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'loops-3',
    blockType: 'loops',
    label: 'Loops contact property enricher',
    prompt:
        'Create a scheduled workflow that reads a Sim table of contacts missing key custom properties, enriches each one using Clay or web research, updates the matching contact in Loops with the new properties, and tracks enrichment coverage in a table.',
    iconId: 'brand/loops-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'loops-4',
    blockType: 'loops',
    label: 'Loops signup welcome flow',
    prompt:
        'Build a workflow that on a new product signup creates the contact in Loops with their plan and source, sends a transactional welcome email, and fires a signup event so the onboarding campaign starts automatically.',
    iconId: 'brand/loops-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'loops-5',
    blockType: 'loops',
    label: 'Loops milestone event sender',
    prompt:
        'Create a workflow that watches product usage in a table for key milestones — first integration, team invite, plan upgrade — and sends the matching Loops event for each so lifecycle emails fire on real behavior instead of guesses.',
    iconId: 'brand/loops-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'loops-6',
    blockType: 'loops',
    label: 'Loops churn win-back',
    prompt:
        'Build a scheduled workflow that reads a Sim table of product-usage data to identify users who have gone inactive, sends each a personalized transactional win-back email through Loops, fires a re-engagement event, and logs who was contacted to a table for follow-up.',
    iconId: 'brand/loops-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'luma-0',
    blockType: 'luma',
    label: 'Luma event reminder cadence',
    prompt:
        'Create a workflow that sends scheduled reminders to Luma event registrants — 7 days, 24 hours, 1 hour out — with personalized content based on RSVP type.',
    iconId: 'brand/luma-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'luma-1',
    blockType: 'luma',
    label: 'Luma registrant enricher',
    prompt:
        'Build a scheduled workflow that pulls the Luma event guest list, enriches each registrant with company data via Apollo, and pushes high-value attendees into HubSpot as leads.',
    iconId: 'brand/luma-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'luma-2',
    blockType: 'luma',
    label: 'Luma post-event followup',
    prompt:
        'Create a scheduled workflow that runs the day after a Luma event, pulls the guest list, segments attendees from no-shows, sends each segment a tailored followup, and writes attendance to the CRM.',
    iconId: 'brand/luma-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'luma-3',
    blockType: 'luma',
    label: 'Luma calendar import',
    prompt:
        'Build a scheduled workflow that pulls the Luma event guest list and creates a personalized Google Calendar invite for each new registrant with the event details, location, and prep links.',
    iconId: 'brand/luma-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'luma-4',
    blockType: 'luma',
    label: 'Luma + Discord community sync',
    prompt:
        'Create a scheduled workflow that pulls the Luma event guest list and adds each new registrant to the matching Discord community channel with the right role for event access.',
    iconId: 'brand/luma-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'luma-5',
    blockType: 'luma',
    label: 'Luma event-series analytics',
    prompt:
        'Build a scheduled workflow that pulls Luma event-series data, calculates conversion from registration to attendance to next action, and writes the analytics to a report file.',
    iconId: 'brand/luma-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'luma-6',
    blockType: 'luma',
    label: 'Luma new-registrant welcome',
    prompt:
        'Create a scheduled workflow that pulls the Luma event guest list, finds registrants added since the last run, and sends each a personalized welcome email with what to expect and how to prepare.',
    iconId: 'brand/luma-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mailchimp-0',
    blockType: 'mailchimp',
    label: 'Mailchimp newsletter curator',
    prompt:
        'Create a scheduled weekly workflow that scrapes my favorite industry news sites and blogs, picks the top stories relevant to my audience, writes summaries for each, and drafts a ready-to-send newsletter in Mailchimp.',
    iconId: 'emcn/mail',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mailchimp-1',
    blockType: 'mailchimp',
    label: 'Mailchimp re-engagement campaign',
    prompt:
        'Build a workflow that finds Mailchimp members who have not opened or clicked in 90 days, drafts a re-engagement campaign with a personalized subject line per segment, and schedules it to send to those members only.',
    iconId: 'brand/mailchimp-icon',
    modules: <String>['agent', 'scheduled', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mailchimp-2',
    blockType: 'mailchimp',
    label: 'Mailchimp + SendGrid hybrid sender',
    prompt:
        'Create a workflow that uses Mailchimp for marketing audience management and segmentation but sends the actual campaign through SendGrid for deliverability, syncing send results, opens, and clicks back to the Mailchimp audience as merge fields.',
    iconId: 'brand/mailchimp-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mailchimp-3',
    blockType: 'mailchimp',
    label: 'Mailchimp campaign performance digest',
    prompt:
        'Build a scheduled workflow that pulls the previous week of Mailchimp campaign reports, compares open and click rates against my benchmarks, and posts a Slack digest with the winners, losers, and one-line takeaways.',
    iconId: 'brand/mailchimp-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mailchimp-4',
    blockType: 'mailchimp',
    label: 'Mailchimp + Loops audience sync',
    prompt:
        'Create a workflow that keeps a Mailchimp audience and a Loops mailing list in sync: new Mailchimp subscribers create Loops contacts on the matching list, unsubscribes propagate both ways, and merge fields map cleanly to Loops contact properties.',
    iconId: 'brand/mailchimp-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mailchimp-5',
    blockType: 'mailchimp',
    label: 'Mailchimp event-driven blast',
    prompt:
        'Build a workflow that listens for a launch trigger from my tables, populates a Mailchimp campaign template with the launch details, schedules it to the right segment, and logs the campaign ID and recipient count back to the table.',
    iconId: 'brand/mailchimp-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mailchimp-6',
    blockType: 'mailchimp',
    label: 'Mailchimp segment builder from HubSpot',
    prompt:
        'Create a workflow that reads HubSpot lifecycle stage and ICP fields, upserts each contact into Mailchimp with the matching tags and merge fields, and recomputes named segments daily so marketing can target by CRM state.',
    iconId: 'brand/mailchimp-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mailgun-0',
    blockType: 'mailgun',
    label: 'Mailgun mailing list builder',
    prompt:
        'Create a scheduled workflow that watches a table of contact opt-ins, creates the matching Mailgun mailing lists by segment, adds each new opt-in as a member, and reports list health weekly to a tracking table.',
    iconId: 'brand/mailgun-icon',
    modules: <String>['tables', 'scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mailgun-1',
    blockType: 'mailgun',
    label: 'Mailgun event analytics digest',
    prompt:
        'Build a scheduled workflow that pulls Mailgun message events, aggregates deliveries, opens, clicks, and complaints by tag and domain, and posts a Slack digest with anomalies and the top-performing tags of the day.',
    iconId: 'brand/mailgun-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mailgun-2',
    blockType: 'mailgun',
    label: 'Mailgun transactional sender',
    prompt:
        'Create a workflow that receives a structured event from my application, picks the right Mailgun template and recipient, sends through Mailgun with tracking tags, then retrieves the stored message status for audit.',
    iconId: 'brand/mailgun-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mailgun-3',
    blockType: 'mailgun',
    label: 'Mailgun + Resend transactional fallback',
    prompt:
        'Build a workflow that sends transactional emails through Mailgun by default and automatically falls back to Resend when Mailgun returns a send error or rate-limit response, normalizing the payload and writing every send and the provider used to a delivery table.',
    iconId: 'brand/mailgun-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mailgun-4',
    blockType: 'mailgun',
    label: 'Mailgun deliverability scorecard',
    prompt:
        'Create a scheduled workflow that pulls Mailgun events for the previous week, computes per-domain deliverability, complaint rate, and bounce rate, and generates a scorecard file flagging any sending domain trending toward a deliverability problem.',
    iconId: 'brand/mailgun-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mailgun-5',
    blockType: 'mailgun',
    label: 'Mailgun bounce list hygiene',
    prompt:
        'Build a scheduled workflow that retrieves Mailgun bounce and complaint events, compiles the offending addresses into a suppression table, and posts a summary so the marketing team can audit and clean list hygiene.',
    iconId: 'brand/mailgun-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mailgun-6',
    blockType: 'mailgun',
    label: 'Mailgun domain verification monitor',
    prompt:
        'Create a scheduled workflow that checks the status of each Mailgun sending domain, flags any domain whose SPF, DKIM, or tracking records fall out of verification, and pages the on-call engineer in Slack with the exact records that need fixing.',
    iconId: 'brand/mailgun-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'managed_agent-0',
    blockType: 'managed_agent',
    label: 'Claude Managed Agents overnight refactor',
    prompt:
        'Build a workflow that runs nightly, opens a Claude Managed Agents session against a mounted repository, asks it to work through the migration backlog, and posts the branches it pushed to Slack in the morning.',
    iconId: 'brand/claude-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    featured: true,
  ),
  SuggestionTemplate(
    id: 'managed_agent-1',
    blockType: 'managed_agent',
    label: 'Claude Managed Agents PR reviewer',
    prompt:
        'Create a workflow that triggers on a new GitHub pull request, runs a Claude Managed Agents session over the diff, and posts the findings back as a review comment on the PR.',
    iconId: 'brand/claude-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'managed_agent-2',
    blockType: 'managed_agent',
    label: 'Claude Managed Agents approval gate',
    prompt:
        'Build a workflow that creates a Claude Managed Agents session, polls it for tool calls waiting on permission, posts each one to Slack for a human decision, and sends the allow or deny answer back to the session so it keeps working.',
    iconId: 'brand/claude-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'managed_agent-3',
    blockType: 'managed_agent',
    label: 'Claude Managed Agents research desk',
    prompt:
        'Create a workflow that takes a research question, runs a Claude Managed Agents session to gather and cross-check sources, and writes the findings plus every citation into a table.',
    iconId: 'brand/claude-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'managed_agent-4',
    blockType: 'managed_agent',
    label: 'Claude Managed Agents weekly report',
    prompt:
        'Build a scheduled workflow that runs a Claude Managed Agents session every Monday to compile last week’s metrics into a spreadsheet, then sends the finished file to the leadership list over Gmail.',
    iconId: 'brand/claude-icon',
    modules: <String>['scheduled', 'files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'managed_agent-5',
    blockType: 'managed_agent',
    label: 'Claude Managed Agents support triage',
    prompt:
        'Create a workflow that opens a Claude Managed Agents session per incoming ticket, has it reproduce the issue and draft a reply, and files a Linear issue when it finds a real bug.',
    iconId: 'brand/claude-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'managed_agent-6',
    blockType: 'managed_agent',
    label: 'Claude Managed Agents conversational assistant',
    prompt:
        'Build a workflow that creates a Claude Managed Agents session on the first Slack message in a thread, stores the session id, and sends every later reply in that thread to the same session so the agent keeps its context across runs.',
    iconId: 'brand/claude-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'managed_agent-7',
    blockType: 'managed_agent',
    label: 'Claude Managed Agents run auditor',
    prompt:
        'Create a workflow that reads the event history of a finished Claude Managed Agents session, extracts every tool call and its result, and writes a per-run audit row into a table for compliance review.',
    iconId: 'brand/claude-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'managed_agent-8',
    blockType: 'managed_agent',
    label: 'Claude Managed Agents runaway stopper',
    prompt:
        'Build a scheduled workflow that checks long-running Claude Managed Agents sessions, interrupts any that have been working past a threshold, archives the ones that already finished, and posts what it stopped to Slack.',
    iconId: 'brand/claude-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'manageengine_sdp-0',
    blockType: 'manageengine_sdp',
    label: 'Triage new ServiceDesk Plus requests',
    prompt:
        'Every 15 minutes, list ServiceDesk Plus requests with status Open and no technician assigned. For each one, read the subject and description, decide whether it is a hardware, software, access or network issue, then update the request with the matching category and support group.',
    iconId: 'brand/manage-engine-icon',
    modules: <String>['agent', 'scheduled'],
    providerId: 'manageengine-sdp',
  ),
  SuggestionTemplate(
    id: 'manageengine_sdp-1',
    blockType: 'manageengine_sdp',
    label: 'File a ServiceDesk Plus ticket from Slack',
    prompt:
        'When someone posts in the #it-help Slack channel, create a ServiceDesk Plus request with their message as the description and the first line as the subject, then reply in the thread with the request number.',
    iconId: 'brand/manage-engine-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'manageengine-sdp',
  ),
  SuggestionTemplate(
    id: 'manageengine_sdp-2',
    blockType: 'manageengine_sdp',
    label: 'Daily ServiceDesk Plus SLA breach report',
    prompt:
        'Every weekday at 8am, list ServiceDesk Plus requests whose due-by time has passed and that are not yet resolved. Summarize them by support group and email the summary to the service desk manager.',
    iconId: 'brand/manage-engine-icon',
    modules: <String>['scheduled', 'agent'],
    providerId: 'manageengine-sdp',
  ),
  SuggestionTemplate(
    id: 'manageengine_sdp-3',
    blockType: 'manageengine_sdp',
    label: 'Deflect ServiceDesk Plus tickets with the knowledge base',
    prompt:
        'When a new ServiceDesk Plus request arrives, search ServiceDesk Plus solutions for an article matching its subject. If one is found, add a note to the request quoting the solution and mark it visible to the requester; otherwise assign it to the service desk group.',
    iconId: 'brand/manage-engine-icon',
    modules: <String>['agent'],
    providerId: 'manageengine-sdp',
  ),
  SuggestionTemplate(
    id: 'manageengine_sdp-4',
    blockType: 'manageengine_sdp',
    label: 'Turn a resolved ServiceDesk Plus ticket into a solution',
    prompt:
        'Given a resolved ServiceDesk Plus request ID, read the request and its notes, then draft a knowledge base solution covering the symptom and the fix and create it under the IT Support topic with relevant keywords.',
    iconId: 'brand/manage-engine-icon',
    modules: <String>['agent'],
    providerId: 'manageengine-sdp',
  ),
  SuggestionTemplate(
    id: 'manageengine_sdp-5',
    blockType: 'manageengine_sdp',
    label: 'Escalate recurring ServiceDesk Plus incidents to a problem',
    prompt:
        'Once a day, list ServiceDesk Plus requests created in the last 7 days and group them by category and subcategory. For any category with five or more requests that has no matching open problem, create a problem record describing the pattern and add a note listing the request IDs.',
    iconId: 'brand/manage-engine-icon',
    modules: <String>['scheduled', 'agent'],
    providerId: 'manageengine-sdp',
  ),
  SuggestionTemplate(
    id: 'manageengine_sdp-6',
    blockType: 'manageengine_sdp',
    label: 'Open a ServiceDesk Plus change from an approved plan',
    prompt:
        'When a maintenance plan is approved, create a ServiceDesk Plus change at the Submission stage with status Open, set its scheduled start and end times, assign the change manager, and add a note with the rollout steps.',
    iconId: 'brand/manage-engine-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'manageengine-sdp',
  ),
  SuggestionTemplate(
    id: 'manageengine_sdp-7',
    blockType: 'manageengine_sdp',
    label: 'Post the ServiceDesk Plus change calendar to Slack',
    prompt:
        'Every Monday morning, list ServiceDesk Plus changes scheduled for the coming week and post a summary to the #change-management Slack channel, grouped by change type and showing the owner of each.',
    iconId: 'brand/manage-engine-icon',
    modules: <String>['scheduled', 'workflows'],
    providerId: 'manageengine-sdp',
  ),
  SuggestionTemplate(
    id: 'manageengine_sdp-8',
    blockType: 'manageengine_sdp',
    label: 'Sync ServiceDesk Plus asset inventory to a table',
    prompt:
        'Every night, page through all ServiceDesk Plus assets and write their name, asset tag, serial number, state and assigned user into a Sim table so the inventory can be queried and charted.',
    iconId: 'brand/manage-engine-icon',
    modules: <String>['scheduled', 'tables'],
    providerId: 'manageengine-sdp',
  ),
  SuggestionTemplate(
    id: 'manageengine_sdp-9',
    blockType: 'manageengine_sdp',
    label: 'Reassign ServiceDesk Plus assets when someone leaves',
    prompt:
        'Given a departing employee email, list ServiceDesk Plus assets assigned to them, set each one to the In Store state with a state change comment naming the offboarding ticket, and create a request for IT to collect the hardware.',
    iconId: 'brand/manage-engine-icon',
    modules: <String>['agent'],
    providerId: 'manageengine-sdp',
  ),
  SuggestionTemplate(
    id: 'manageengine_sdp-10',
    blockType: 'manageengine_sdp',
    label: 'Summarize a ServiceDesk Plus ticket thread',
    prompt:
        'Given a ServiceDesk Plus request ID, read the request and all of its notes, then produce a short handover summary covering what was reported, what has been tried, and what the next step should be.',
    iconId: 'brand/manage-engine-icon',
    modules: <String>['agent'],
    providerId: 'manageengine-sdp',
  ),
  SuggestionTemplate(
    id: 'mem0-0',
    blockType: 'mem0',
    label: 'Mem0 long-term agent memory',
    prompt:
        'Build an agent that uses Mem0 to remember user preferences and prior conversations across sessions, so follow-up requests reference real history instead of starting from scratch.',
    iconId: 'brand/mem0-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mem0-1',
    blockType: 'mem0',
    label: 'Mem0 sales-assistant memory',
    prompt:
        'Create a sales agent that persists per-account context in Mem0 — last call notes, open objections, agreed next steps — so every rep starts a follow-up call already up to speed.',
    iconId: 'brand/mem0-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mem0-2',
    blockType: 'mem0',
    label: 'Mem0 + Zep hybrid memory agent',
    prompt:
        'Create a chat agent that uses Mem0 for persistent user preferences and Zep for in-session continuity, so the agent recalls long-term context while staying coherent turn-to-turn.',
    iconId: 'brand/mem0-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mem0-3',
    blockType: 'mem0',
    label: 'Mem0 + Slack assistant memory',
    prompt:
        'Build a Slack bot that uses Mem0 to remember user preferences and prior conversations, so each follow-up question lands in context instead of starting fresh.',
    iconId: 'brand/mem0-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mem0-4',
    blockType: 'mem0',
    label: 'Mem0 + Notion personal-knowledge agent',
    prompt:
        'Create an agent that uses Mem0 to recall personal context and Notion as the source-of-truth knowledge base, answering questions with citations plus user-specific memory.',
    iconId: 'brand/mem0-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mem0-5',
    blockType: 'mem0',
    label: 'Mem0 customer-preference store',
    prompt:
        'Build a workflow that captures customer preferences from support interactions into Mem0 keyed by account, so future automations reference the real preferences.',
    iconId: 'brand/mem0-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mem0-6',
    blockType: 'mem0',
    label: 'Mem0 onboarding-context agent',
    prompt:
        'Create an onboarding agent that adds each new user’s role, goals, and stack to Mem0 on first contact, then searches that memory on every later session so guidance stays tailored to the individual instead of generic.',
    iconId: 'brand/mem0-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'microsoft_ad-0',
    blockType: 'microsoft_ad',
    label: 'Azure AD provisioning',
    prompt:
        'Build a workflow that on a Workday new-hire event creates the Azure AD user account, assigns the right group memberships, and writes the provisioning record to an audit table.',
    iconId: 'brand/azure-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'microsoft-ad',
  ),
  SuggestionTemplate(
    id: 'microsoft_ad-1',
    blockType: 'microsoft_ad',
    label: 'Azure AD offboarding sweep',
    prompt:
        'Create a workflow that on a Workday termination disables the Azure AD account, removes its group memberships, and writes the security audit record.',
    iconId: 'brand/azure-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'microsoft-ad',
  ),
  SuggestionTemplate(
    id: 'microsoft_ad-2',
    blockType: 'microsoft_ad',
    label: 'Azure AD access review',
    prompt:
        'Build a scheduled quarterly workflow that lists Azure AD group memberships, requests owner attestation in Microsoft Teams, and writes the audit log to a compliance table.',
    iconId: 'brand/azure-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'microsoft-ad',
  ),
  SuggestionTemplate(
    id: 'microsoft_ad-3',
    blockType: 'microsoft_ad',
    label: 'Azure AD password-age reminder',
    prompt:
        'Create a scheduled workflow that lists Azure AD users, flags accounts whose last password change is older than the policy window, sends targeted reset reminders, and writes the compliance audit.',
    iconId: 'brand/azure-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'microsoft-ad',
  ),
  SuggestionTemplate(
    id: 'microsoft_ad-4',
    blockType: 'microsoft_ad',
    label: 'Azure AD stale-account sweeper',
    prompt:
        'Build a scheduled workflow that lists Azure AD accounts inactive for 90+ days, requests owner re-attestation, and disables accounts that fail attestation.',
    iconId: 'brand/azure-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'microsoft-ad',
  ),
  SuggestionTemplate(
    id: 'microsoft_ad-5',
    blockType: 'microsoft_ad',
    label: 'Azure AD privileged-group auditor',
    prompt:
        'Create a scheduled monthly workflow that lists the members of privileged Azure AD groups, requests owner attestation for each, and writes the review to an audit table.',
    iconId: 'brand/azure-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'microsoft-ad',
  ),
  SuggestionTemplate(
    id: 'microsoft_ad-6',
    blockType: 'microsoft_ad',
    label: 'Azure AD privileged-access monitor',
    prompt:
        'Build a scheduled workflow that lists privileged Azure AD group members each run, compares against the last snapshot in a table, and pings the security Microsoft Teams channel on any add or removal.',
    iconId: 'brand/azure-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'microsoft-ad',
  ),
  SuggestionTemplate(
    id: 'microsoft_dataverse-0',
    blockType: 'microsoft_dataverse',
    label: 'Dataverse record sync',
    prompt:
        'Build a scheduled workflow that mirrors records between Microsoft Dataverse and a Sim table, normalizes schemas, and posts conflict reports to Slack.',
    iconId: 'brand/microsoft-dataverse-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'microsoft-dataverse',
  ),
  SuggestionTemplate(
    id: 'microsoft_dataverse-1',
    blockType: 'microsoft_dataverse',
    label: 'Dataverse approval workflow',
    prompt:
        'Create a scheduled workflow that polls Dataverse for new high-value records, posts an adaptive card approval to Microsoft Teams, captures the decision, and updates the record.',
    iconId: 'brand/microsoft-dataverse-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'microsoft-dataverse',
  ),
  SuggestionTemplate(
    id: 'microsoft_dataverse-2',
    blockType: 'microsoft_dataverse',
    label: 'Dataverse data-quality auditor',
    prompt:
        'Build a scheduled workflow that scans Dataverse tables for missing required fields, format violations, and duplicates, and writes a remediation backlog to a tracking table.',
    iconId: 'brand/microsoft-dataverse-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'microsoft-dataverse',
  ),
  SuggestionTemplate(
    id: 'microsoft_dataverse-3',
    blockType: 'microsoft_dataverse',
    label: 'Dataverse + Power BI feeder',
    prompt:
        'Create a workflow that pulls Dataverse entity data daily, transforms it into BI-ready rows in a Sim table, and stages a refresh signal for downstream Power BI consumption.',
    iconId: 'brand/microsoft-dataverse-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'microsoft-dataverse',
  ),
  SuggestionTemplate(
    id: 'microsoft_dataverse-4',
    blockType: 'microsoft_dataverse',
    label: 'Dataverse legacy CRM bridge',
    prompt:
        'Build a workflow that mirrors Salesforce contacts into Microsoft Dataverse and back, mapping fields and resolving conflicts deterministically so both CRMs stay in sync during migration.',
    iconId: 'brand/microsoft-dataverse-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'microsoft-dataverse',
  ),
  SuggestionTemplate(
    id: 'microsoft_dataverse-5',
    blockType: 'microsoft_dataverse',
    label: 'Dataverse compliance archiver',
    prompt:
        'Create a scheduled workflow that exports Dataverse records older than the retention horizon into long-term storage, removes them from the live table, and writes the archive manifest for auditors.',
    iconId: 'brand/microsoft-dataverse-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'microsoft-dataverse',
  ),
  SuggestionTemplate(
    id: 'microsoft_dataverse-6',
    blockType: 'microsoft_dataverse',
    label: 'Dataverse case-routing agent',
    prompt:
        'Build a workflow that runs a relevance search across Microsoft Dataverse case and account tables when a new support request arrives, classifies the issue, upserts the case record with the right owner and priority, and notifies the assigned team in Microsoft Teams.',
    iconId: 'brand/microsoft-dataverse-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'microsoft-dataverse',
  ),
  SuggestionTemplate(
    id: 'microsoft_dynamics_365-0',
    blockType: 'microsoft_dynamics_365',
    label: 'Dynamics lead intake',
    prompt:
        'Build a workflow that receives a new prospect, searches Microsoft Dynamics 365 CRM for a matching lead, creates the lead when no match exists, and notifies the sales team in Microsoft Teams.',
    iconId: 'brand/microsoft-dataverse-icon',
    modules: <String>['agent', 'workflows'],
    featured: true,
    providerId: 'microsoft-dataverse',
  ),
  SuggestionTemplate(
    id: 'microsoft_dynamics_365-1',
    blockType: 'microsoft_dynamics_365',
    label: 'Dynamics lead qualification',
    prompt:
        'Create a workflow that retrieves a Dynamics 365 lead after a qualification decision, qualifies it with the requested account, contact, and opportunity choices, and sends the resulting entity references to Microsoft Teams.',
    iconId: 'brand/microsoft-dataverse-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'microsoft-dataverse',
  ),
  SuggestionTemplate(
    id: 'microsoft_dynamics_365-2',
    blockType: 'microsoft_dynamics_365',
    label: 'Dynamics customer sync',
    prompt:
        'Build a scheduled workflow that lists Dynamics 365 accounts and contacts, normalizes the current page into a Sim table, and updates matching CRM records when approved source data changes.',
    iconId: 'brand/microsoft-dataverse-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'microsoft-dataverse',
  ),
  SuggestionTemplate(
    id: 'microsoft_dynamics_365-3',
    blockType: 'microsoft_dynamics_365',
    label: 'Dynamics pipeline review',
    prompt:
        'Create a scheduled workflow that lists open Dynamics 365 opportunities with an OData filter, summarizes the current page by owner and expected close date, and posts the review to Slack.',
    iconId: 'brand/microsoft-dataverse-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    featured: true,
    providerId: 'microsoft-dataverse',
  ),
  SuggestionTemplate(
    id: 'microsoft_dynamics_365-4',
    blockType: 'microsoft_dynamics_365',
    label: 'Dynamics stale deal follow-up',
    prompt:
        'Build a scheduled workflow that lists Dynamics 365 opportunities with old activity dates, retrieves customer context, drafts follow-up messages in Outlook, and updates the reviewed opportunities with your organization’s approved fields.',
    iconId: 'brand/microsoft-dataverse-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'microsoft-dataverse',
  ),
  SuggestionTemplate(
    id: 'microsoft_dynamics_365-5',
    blockType: 'microsoft_dynamics_365',
    label: 'Dynamics closed-deal handoff',
    prompt:
        'Create a workflow that closes an approved Dynamics 365 opportunity as won or lost, retrieves the related CRM context, and posts a handoff summary to Microsoft Teams.',
    iconId: 'brand/microsoft-dataverse-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'microsoft-dataverse',
  ),
  SuggestionTemplate(
    id: 'microsoft_dynamics_365-6',
    blockType: 'microsoft_dynamics_365',
    label: 'Dynamics case routing',
    prompt:
        'Build a workflow that searches Dynamics 365 for customer and case context, lists candidate users or owner-capable teams, assigns the case to the selected owner, and notifies the support channel in Microsoft Teams.',
    iconId: 'brand/microsoft-dataverse-icon',
    modules: <String>['agent', 'workflows'],
    featured: true,
    providerId: 'microsoft-dataverse',
  ),
  SuggestionTemplate(
    id: 'microsoft_dynamics_365-7',
    blockType: 'microsoft_dynamics_365',
    label: 'Dynamics case resolution',
    prompt:
        'Create a workflow that retrieves an approved Dynamics 365 case, records the resolution subject, notes, and time spent, resolves the case, and sends the customer a follow-up through Outlook.',
    iconId: 'brand/microsoft-dataverse-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'microsoft-dataverse',
  ),
  SuggestionTemplate(
    id: 'microsoft_excel-0',
    blockType: 'microsoft_excel',
    label: 'Excel financial close automator',
    prompt:
        'Build a scheduled workflow that closes the books each period — pulls Stripe and accounting data, updates a Microsoft Excel close workbook, and emails the controller the reconciled file.',
    iconId: 'brand/microsoft-excel-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'microsoft-excel',
  ),
  SuggestionTemplate(
    id: 'microsoft_excel-1',
    blockType: 'microsoft_excel',
    label: 'Excel invoice generator',
    prompt:
        'Create a workflow that reads a sales orders table, populates an existing Microsoft Excel invoice worksheet per order, and posts the workbook link for finance review.',
    iconId: 'brand/microsoft-excel-icon',
    modules: <String>['tables', 'files', 'agent', 'workflows'],
    providerId: 'microsoft-excel',
  ),
  SuggestionTemplate(
    id: 'microsoft_excel-2',
    blockType: 'microsoft_excel',
    label: 'Excel report table refresher',
    prompt:
        'Build a scheduled workflow that reads rows from a source, updates a Microsoft Excel report table, and posts the workbook link to a Microsoft Teams channel.',
    iconId: 'brand/microsoft-excel-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
    providerId: 'microsoft-excel',
  ),
  SuggestionTemplate(
    id: 'microsoft_excel-3',
    blockType: 'microsoft_excel',
    label: 'Excel + SharePoint forecast hub',
    prompt:
        'Create a workflow that aggregates regional forecasts submitted in Microsoft Excel files on SharePoint, normalizes formats, and writes a consolidated forecast table for leadership.',
    iconId: 'brand/microsoft-excel-icon',
    modules: <String>['files', 'tables', 'agent', 'workflows'],
    providerId: 'microsoft-excel',
  ),
  SuggestionTemplate(
    id: 'microsoft_excel-4',
    blockType: 'microsoft_excel',
    label: 'Excel commission calculator',
    prompt:
        'Build a workflow that pulls closed Salesforce deals each month, computes commission per rep using a Microsoft Excel commission model, and emails the per-rep statements.',
    iconId: 'brand/microsoft-excel-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
    providerId: 'microsoft-excel',
  ),
  SuggestionTemplate(
    id: 'microsoft_excel-5',
    blockType: 'microsoft_excel',
    label: 'Excel scenario modeler',
    prompt:
        'Create a workflow that runs scenarios against a Microsoft Excel financial model — pessimistic, base, optimistic — captures outputs, and writes a comparison report to a finance file.',
    iconId: 'brand/microsoft-excel-icon',
    modules: <String>['files', 'agent', 'workflows'],
    providerId: 'microsoft-excel',
  ),
  SuggestionTemplate(
    id: 'microsoft_excel-6',
    blockType: 'microsoft_excel',
    label: 'Excel + Power BI feeder',
    prompt:
        'Build a scheduled workflow that updates a Microsoft Excel data table from a Sim source, keeps its table ready for Power BI consumption, and notifies BI consumers in Teams.',
    iconId: 'brand/microsoft-excel-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'microsoft-excel',
  ),
  SuggestionTemplate(
    id: 'microsoft_planner-0',
    blockType: 'microsoft_planner',
    label: 'Microsoft Planner sprint digest',
    prompt:
        'Create a scheduled weekly workflow that pulls Microsoft Planner bucket progress, computes completion rate per bucket, and posts a status digest to the project Microsoft Teams channel.',
    iconId: 'brand/microsoft-planner-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'microsoft-planner',
  ),
  SuggestionTemplate(
    id: 'microsoft_planner-1',
    blockType: 'microsoft_planner',
    label: 'Microsoft Planner SLA monitor',
    prompt:
        'Build a workflow that watches Microsoft Planner tasks with due dates, sends reminders 24 hours before, and escalates to managers in Teams when items breach SLA.',
    iconId: 'brand/microsoft-planner-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'microsoft-planner',
  ),
  SuggestionTemplate(
    id: 'microsoft_planner-2',
    blockType: 'microsoft_planner',
    label: 'Microsoft Planner Excel-import',
    prompt:
        'Create a workflow that takes a Microsoft Excel task list, creates matching Planner tasks in the right bucket, and writes the planner IDs back to the spreadsheet for tracking.',
    iconId: 'brand/microsoft-planner-icon',
    modules: <String>['files', 'agent', 'workflows'],
    providerId: 'microsoft-planner',
  ),
  SuggestionTemplate(
    id: 'microsoft_planner-3',
    blockType: 'microsoft_planner',
    label: 'Microsoft Planner blocker watcher',
    prompt:
        'Build a scheduled workflow that scans Microsoft Planner tasks tagged blocked, identifies the blocking party, and posts a Teams ping with the context to unblock the work.',
    iconId: 'brand/microsoft-planner-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'microsoft-planner',
  ),
  SuggestionTemplate(
    id: 'microsoft_planner-4',
    blockType: 'microsoft_planner',
    label: 'Microsoft Planner template launcher',
    prompt:
        'Create a scheduled workflow that polls Microsoft Dataverse for new projects and creates a Planner plan from the project template, populates the standard buckets, and assigns the right owners.',
    iconId: 'brand/microsoft-planner-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'microsoft-planner',
  ),
  SuggestionTemplate(
    id: 'microsoft_planner-5',
    blockType: 'microsoft_planner',
    label: 'Microsoft Planner retrospective',
    prompt:
        'Build a scheduled workflow that runs at the end of a sprint, pulls completed Microsoft Planner tasks, summarizes wins and patterns, and writes the retro doc to a SharePoint page.',
    iconId: 'brand/microsoft-planner-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'microsoft-planner',
  ),
  SuggestionTemplate(
    id: 'microsoft_planner-6',
    blockType: 'microsoft_planner',
    label: 'Microsoft Planner workload balancer',
    prompt:
        'Create a scheduled weekly workflow that audits Microsoft Planner assignment load per team member, suggests rebalancing, and posts the recommendations to the manager in Teams.',
    iconId: 'brand/microsoft-planner-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'microsoft-planner',
  ),
  SuggestionTemplate(
    id: 'microsoft_teams-0',
    blockType: 'microsoft_teams',
    label: 'Microsoft Teams daily brief',
    prompt:
        'Build a scheduled workflow that pulls updates from your project tools — GitHub commits, Jira ticket status changes, and calendar events — and posts a formatted daily brief to your Microsoft Teams channel each morning.',
    iconId: 'brand/microsoft-teams-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'microsoft-teams',
  ),
  SuggestionTemplate(
    id: 'microsoft_teams-1',
    blockType: 'microsoft_teams',
    label: 'Teams incident war room',
    prompt:
        'Build a workflow triggered by a PagerDuty incident that creates a Microsoft Teams war-room channel, invites responders, posts the incident summary, and keeps the channel name in sync with incident state.',
    iconId: 'brand/microsoft-teams-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'microsoft-teams',
  ),
  SuggestionTemplate(
    id: 'microsoft_teams-2',
    blockType: 'microsoft_teams',
    label: 'Teams sales-deal channel',
    prompt:
        'Create a workflow that listens for new Salesforce opportunities above a threshold, creates a Microsoft Teams channel for the deal, invites the account team, and pins the opportunity link.',
    iconId: 'brand/microsoft-teams-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'microsoft-teams',
  ),
  SuggestionTemplate(
    id: 'microsoft_teams-3',
    blockType: 'microsoft_teams',
    label: 'Teams approval router',
    prompt:
        'Build a workflow that posts approval requests with quick-action buttons in Microsoft Teams, captures the decision, writes it back to the source record, and notifies the requester.',
    iconId: 'brand/microsoft-teams-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'microsoft-teams',
  ),
  SuggestionTemplate(
    id: 'microsoft_teams-4',
    blockType: 'microsoft_teams',
    label: 'Teams weekly metrics digest',
    prompt:
        'Create a scheduled weekly workflow that aggregates key business metrics from Stripe and HubSpot, formats them into a polished Microsoft Teams adaptive card, and posts to the leadership channel.',
    iconId: 'brand/microsoft-teams-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'microsoft-teams',
  ),
  SuggestionTemplate(
    id: 'microsoft_teams-5',
    blockType: 'microsoft_teams',
    label: 'Teams onboarding bot',
    prompt:
        'Build a Microsoft Teams bot that greets new hires when added to the org, walks them through onboarding tasks with progress checkboxes, and writes completion status to an HR table.',
    iconId: 'brand/microsoft-teams-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'microsoft-teams',
  ),
  SuggestionTemplate(
    id: 'microsoft_teams-6',
    blockType: 'microsoft_teams',
    label: 'Teams ticket-bridge for Zendesk',
    prompt:
        'Create a workflow that mirrors high-priority Zendesk tickets into Microsoft Teams channels, keeps replies synced both ways, and closes the Teams thread when the ticket is resolved.',
    iconId: 'brand/microsoft-teams-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'microsoft-teams',
  ),
  SuggestionTemplate(
    id: 'microsoft_word-0',
    blockType: 'microsoft_word',
    label: 'Word meeting-notes writer',
    prompt:
        'Build a workflow that takes a Fireflies meeting transcript, summarizes the decisions and action items, and creates a formatted Word document in the team OneDrive folder.',
    iconId: 'brand/microsoft-word-icon',
    modules: <String>['agent', 'files', 'workflows'],
    providerId: 'microsoft-word',
  ),
  SuggestionTemplate(
    id: 'microsoft_word-1',
    blockType: 'microsoft_word',
    label: 'Word contract reviewer',
    prompt:
        'Create a workflow that reads a Word contract, flags clauses that deviate from the standard template, writes the findings to a table, and posts a review summary in Teams.',
    iconId: 'brand/microsoft-word-icon',
    modules: <String>['agent', 'tables', 'workflows'],
    providerId: 'microsoft-word',
  ),
  SuggestionTemplate(
    id: 'microsoft_word-2',
    blockType: 'microsoft_word',
    label: 'Word weekly-report builder',
    prompt:
        'Build a scheduled weekly workflow that pulls metrics from a table, drafts a written status report, and appends the new week to a running Word document.',
    iconId: 'brand/microsoft-word-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'microsoft-word',
  ),
  SuggestionTemplate(
    id: 'microsoft_word-3',
    blockType: 'microsoft_word',
    label: 'Word proposal generator',
    prompt:
        'Create a workflow triggered by a closed-won HubSpot deal that generates a tailored proposal document in Word, exports it as PDF, and emails it to the customer contact.',
    iconId: 'brand/microsoft-word-icon',
    modules: <String>['agent', 'files', 'workflows'],
    providerId: 'microsoft-word',
  ),
  SuggestionTemplate(
    id: 'microsoft_word-4',
    blockType: 'microsoft_word',
    label: 'Word document knowledge sync',
    prompt:
        'Build a scheduled workflow that lists Word documents in a SharePoint library, reads each one, and syncs the extracted text into a knowledge base for retrieval.',
    iconId: 'brand/microsoft-word-icon',
    modules: <String>['scheduled', 'knowledge-base', 'agent', 'workflows'],
    providerId: 'microsoft-word',
  ),
  SuggestionTemplate(
    id: 'microsoft_word-5',
    blockType: 'microsoft_word',
    label: 'Word policy translator',
    prompt:
        'Create a workflow that reads an internal policy document from Word, translates it into the requested language, and creates a localized Word copy alongside the original.',
    iconId: 'brand/microsoft-word-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'microsoft-word',
  ),
  SuggestionTemplate(
    id: 'microsoft_word-6',
    blockType: 'microsoft_word',
    label: 'Word incident postmortem',
    prompt:
        'Build a workflow triggered by a resolved Linear incident that drafts a postmortem in Word from the issue timeline, exports it as PDF, and shares the PDF in the incident Slack channel.',
    iconId: 'brand/microsoft-word-icon',
    modules: <String>['agent', 'files', 'workflows'],
    providerId: 'microsoft-word',
  ),
  SuggestionTemplate(
    id: 'mintlify-0',
    blockType: 'mintlify',
    label: 'Mintlify release-notes publisher',
    prompt:
        'Build a workflow that reads merged pull requests from GitHub, has an agent draft release notes, creates a Mintlify agent job to add them to the changelog, and triggers a docs deployment once the pull request merges.',
    iconId: 'brand/mintlify-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mintlify-1',
    blockType: 'mintlify',
    label: 'Mintlify docs-gap reporter',
    prompt:
        'Create a scheduled workflow that exports Mintlify assistant conversations weekly, filters the ones marked unanswered, groups them into themes, and posts the top documentation gaps to Slack.',
    iconId: 'brand/mintlify-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mintlify-2',
    blockType: 'mintlify',
    label: 'Mintlify support answer bot',
    prompt:
        'Build a workflow that takes an inbound support question, asks the Mintlify docs assistant for an answer, and replies in Slack with the answer and its cited documentation links.',
    iconId: 'brand/mintlify-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mintlify-3',
    blockType: 'mintlify',
    label: 'Mintlify preview deployment on PR',
    prompt:
        'Create a workflow that triggers a Mintlify preview deployment for a Git branch, polls the deployment status until it succeeds or fails, and comments the preview URL on the GitHub pull request.',
    iconId: 'brand/mintlify-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mintlify-4',
    blockType: 'mintlify',
    label: 'Mintlify prose-quality sweeper',
    prompt:
        'Build a scheduled workflow that reads documentation pages from a table, runs the Mintlify AI-prose detector on each one, and writes flagged passages and suggested rewrites back to the table for review.',
    iconId: 'brand/mintlify-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mintlify-5',
    blockType: 'mintlify',
    label: 'Mintlify feedback triage',
    prompt:
        'Create a scheduled workflow that exports Mintlify user feedback daily, has an agent classify each comment by severity and theme, and opens Linear issues for the ones that need a documentation fix.',
    iconId: 'brand/mintlify-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mintlify-6',
    blockType: 'mintlify',
    label: 'Mintlify traffic digest',
    prompt:
        'Build a scheduled workflow that exports Mintlify page views, unique visitors, and top search queries each week, writes them to a table, and emails a digest highlighting pages with rising AI traffic.',
    iconId: 'brand/mintlify-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mintlify-7',
    blockType: 'mintlify',
    label: 'Mintlify knowledge base mirror',
    prompt:
        'Create a workflow that searches a Mintlify documentation site, fetches the full content of each matching page, and loads it into a Sim knowledge base so agents can retrieve it offline.',
    iconId: 'brand/mintlify-icon',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mistral_parse-0',
    blockType: 'mistral_parse',
    label: 'Mistral Parser for complex PDFs',
    prompt:
        'Create a workflow that uses Mistral Parser to convert dense research PDFs into clean Markdown, saves the Markdown to files, and indexes them into a knowledge base for downstream agents.',
    iconId: 'brand/mistral-icon',
    modules: <String>['knowledge-base', 'files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mistral_parse-1',
    blockType: 'mistral_parse',
    label: 'Mistral Parser bank statement reader',
    prompt:
        'Create a workflow that uses Mistral Parser to extract structured transactions from uploaded bank statement PDFs, writes each transaction to a finance table, and classifies expense category.',
    iconId: 'brand/mistral-icon',
    modules: <String>['tables', 'files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mistral_parse-2',
    blockType: 'mistral_parse',
    label: 'Mistral Parser research-paper digester',
    prompt:
        'Build a scheduled workflow that watches a research-paper folder, parses each PDF with Mistral Parser, and writes clean Markdown summaries for the knowledge base.',
    iconId: 'brand/mistral-icon',
    modules: <String>['knowledge-base', 'files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mistral_parse-3',
    blockType: 'mistral_parse',
    label: 'Mistral Parser legal-doc summarizer',
    prompt:
        'Create a workflow that processes legal documents with Mistral Parser, extracts the key clauses and obligations into a table, and writes a one-pager summary file.',
    iconId: 'brand/mistral-icon',
    modules: <String>['files', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mistral_parse-4',
    blockType: 'mistral_parse',
    label: 'Mistral Parser invoice intake',
    prompt:
        'Build a workflow that runs each incoming invoice PDF through Mistral Parser, extracts vendor, line items, totals, and due date into an accounts-payable table, and flags any invoice missing a PO number for the finance team in Slack.',
    iconId: 'brand/mistral-icon',
    modules: <String>['files', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mistral_parse-5',
    blockType: 'mistral_parse',
    label: 'Mistral Parser scanned-contract indexer',
    prompt:
        'Create a workflow that parses scanned, image-only contracts with Mistral Parser OCR, converts them to searchable Markdown, and indexes the result into a knowledge base so legal can search obligations across every signed agreement.',
    iconId: 'brand/mistral-icon',
    modules: <String>['knowledge-base', 'files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mistral_parse-6',
    blockType: 'mistral_parse',
    label: 'Mistral Parser resume screener',
    prompt:
        'Build a workflow that parses uploaded resume PDFs with Mistral Parser, extracts candidate skills, experience, and contact details into a hiring table, and posts a shortlist summary to the recruiting channel in Slack.',
    iconId: 'brand/mistral-icon',
    modules: <String>['files', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'modal-0',
    blockType: 'modal',
    label: 'Modal GPU inference',
    prompt:
        'Build a workflow where an agent receives a question, calls a deployed Modal Web Function that runs a GPU model, and replies with the model output.',
    iconId: 'brand/modal-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'modal-1',
    blockType: 'modal',
    label: 'Modal self-hosted chat',
    prompt:
        'Create a workflow that answers incoming Slack messages by generating a chat completion on a Modal Endpoint running an open-weight model, then posts the reply back to the thread.',
    iconId: 'brand/modal-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'modal-2',
    blockType: 'modal',
    label: 'Modal batch scoring',
    prompt:
        'Build a scheduled workflow that reads pending rows from a table, calls a deployed Modal function to score each one, and writes the scores back to the table.',
    iconId: 'brand/modal-icon',
    modules: <String>['scheduled', 'tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'modal-3',
    blockType: 'modal',
    label: 'Modal document summarizer',
    prompt:
        'Create a workflow that takes an uploaded document, sends its text to a Modal Endpoint for summarization, and emails the summary back to the requester.',
    iconId: 'brand/modal-icon',
    modules: <String>['files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'modal-4',
    blockType: 'modal',
    label: 'Modal endpoint health check',
    prompt:
        'Build a scheduled workflow that lists the models a Modal token can reach, sends a short test completion to each one, records the latency in a table, and alerts the engineering channel when an endpoint stops responding.',
    iconId: 'brand/modal-icon',
    modules: <String>['scheduled', 'tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'modal-5',
    blockType: 'modal',
    label: 'Modal image generation',
    prompt:
        'Create a workflow that takes a prompt from a form, calls a deployed Modal function that generates an image, and shares the result in Slack.',
    iconId: 'brand/modal-icon',
    modules: <String>['workflows'],
  ),
  SuggestionTemplate(
    id: 'modal-6',
    blockType: 'modal',
    label: 'Modal model comparison',
    prompt:
        'Build a workflow that sends the same prompt to two Modal Endpoints, has an agent compare the two completions for accuracy and tone, and writes the verdict to a table.',
    iconId: 'brand/modal-icon',
    modules: <String>['agent', 'tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'modal-7',
    blockType: 'modal',
    label: 'Modal enrichment pipeline',
    prompt:
        'Create a workflow triggered when a new record lands in a table that calls a deployed Modal function to extract structured fields from the raw text, then updates the record with the extracted values.',
    iconId: 'brand/modal-icon',
    modules: <String>['tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'monday-0',
    blockType: 'monday',
    label: 'Monday status digest',
    prompt:
        'Create a scheduled weekly workflow that pulls Monday board progress, computes completion rate, and posts a status update to leadership Slack with the at-risk items highlighted.',
    iconId: 'brand/monday-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'monday',
  ),
  SuggestionTemplate(
    id: 'monday-1',
    blockType: 'monday',
    label: 'Monday board automator',
    prompt:
        'Build a workflow that watches Monday boards for status changes, applies branching automations — assign owners, set due dates, post Slack updates — based on a rules table.',
    iconId: 'brand/monday-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'monday',
  ),
  SuggestionTemplate(
    id: 'monday-2',
    blockType: 'monday',
    label: 'Monday client portal',
    prompt:
        'Create a workflow that mirrors a Monday project board into a client-facing summary table, refreshes hourly, and emails the client a snapshot link each week.',
    iconId: 'brand/monday-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'monday',
  ),
  SuggestionTemplate(
    id: 'monday-3',
    blockType: 'monday',
    label: 'Monday SLA enforcer',
    prompt:
        'Build a workflow that watches Monday items with due dates, sends reminders 24 hours before, and escalates to managers when items breach SLA.',
    iconId: 'brand/monday-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'monday',
  ),
  SuggestionTemplate(
    id: 'monday-4',
    blockType: 'monday',
    label: 'Monday + CRM sync',
    prompt:
        'Create a workflow that mirrors Monday CRM board items into Salesforce as opportunities, keeps stage and amount synced, and writes the Salesforce ID back to the Monday item.',
    iconId: 'brand/monday-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'monday',
  ),
  SuggestionTemplate(
    id: 'monday-5',
    blockType: 'monday',
    label: 'Monday workspace audit',
    prompt:
        'Build a scheduled monthly workflow that audits Monday boards for unused columns, stale automations, and missing owners, and writes a cleanup plan to a tracking table.',
    iconId: 'brand/monday-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'monday',
  ),
  SuggestionTemplate(
    id: 'monday-6',
    blockType: 'monday',
    label: 'Monday onboarding kickoff',
    prompt:
        'Create a workflow that on a new hire in Workday creates a personalized Monday onboarding board, seeds the role-specific tasks, and invites the new hire and buddy.',
    iconId: 'brand/monday-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'monday',
  ),
  SuggestionTemplate(
    id: 'mongodb-0',
    blockType: 'mongodb',
    label: 'MongoDB to data lake export',
    prompt:
        'Build a scheduled workflow that runs each night, exports MongoDB collections to S3 with partitioned Parquet files, and registers them in an Athena-queryable catalog.',
    iconId: 'brand/mongo-db-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mongodb-1',
    blockType: 'mongodb',
    label: 'MongoDB index health monitor',
    prompt:
        'Create a scheduled workflow that scans MongoDB collections for slow queries and missing indexes, writes a remediation table, and opens Linear tickets for the worst offenders.',
    iconId: 'brand/mongo-db-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mongodb-2',
    blockType: 'mongodb',
    label: 'MongoDB to vector enrichment',
    prompt:
        'Build a scheduled workflow that polls a MongoDB collection for new documents, generates OpenAI embeddings, and upserts them into Pinecone with the source document ID for retrieval.',
    iconId: 'brand/mongo-db-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mongodb-3',
    blockType: 'mongodb',
    label: 'MongoDB user-event triage',
    prompt:
        'Create a scheduled workflow that polls a MongoDB user-events collection for new records, classifies events as engagement or risk signals, and writes high-priority items to a triage table.',
    iconId: 'brand/mongo-db-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mongodb-4',
    blockType: 'mongodb',
    label: 'MongoDB orphaned-doc cleaner',
    prompt:
        'Build a scheduled workflow that runs weekly, finds orphaned references in MongoDB, dry-runs the cleanup plan, posts to Slack for approval, and executes once approved.',
    iconId: 'brand/mongo-db-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mongodb-5',
    blockType: 'mongodb',
    label: 'MongoDB query digest',
    prompt:
        'Create a scheduled daily workflow that aggregates MongoDB query telemetry from the profiler, identifies the top-cost queries, and posts a Slack engineering digest.',
    iconId: 'brand/mongo-db-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mongodb-6',
    blockType: 'mongodb',
    label: 'MongoDB + Tinybird feeder',
    prompt:
        'Build a scheduled workflow that batches new MongoDB records into a Tinybird pipe on a short interval, exposes the data to downstream apps, and writes the load metrics to a table.',
    iconId: 'brand/mongo-db-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mssql-0',
    blockType: 'mssql',
    label: 'Ask SQL Server in plain English',
    prompt:
        'Build a workflow that takes a natural-language question, has an agent turn it into a T-SQL SELECT, runs it against Microsoft SQL Server, and returns the resulting rows as a readable answer.',
    iconId: 'brand/microsoft-sql-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mssql-1',
    blockType: 'mssql',
    label: 'SQL Server metrics digest to Slack',
    prompt:
        'Create a scheduled workflow that queries key business metrics from Microsoft SQL Server each morning, has an agent summarize the numbers and notable changes, and posts the digest to a Slack channel.',
    iconId: 'brand/microsoft-sql-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mssql-2',
    blockType: 'mssql',
    label: 'Document your SQL Server schema',
    prompt:
        'Build a workflow that introspects a Microsoft SQL Server schema to list its tables, columns, keys, and indexes, then has an agent write plain-English documentation describing what each table holds.',
    iconId: 'brand/microsoft-sql-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mssql-3',
    blockType: 'mssql',
    label: 'Merge records into SQL Server',
    prompt:
        'Create a workflow that takes incoming records and runs a T-SQL MERGE against Microsoft SQL Server so each row is inserted when new and updated when it already exists, keeping the table free of duplicates.',
    iconId: 'brand/microsoft-sql-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mssql-4',
    blockType: 'mssql',
    label: 'Nightly SQL Server data cleanup',
    prompt:
        'Build a scheduled workflow that deletes rows in Microsoft SQL Server older than a retention cutoff and reports how many rows were removed, so tables stay lean on an interval.',
    iconId: 'brand/microsoft-sql-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mssql-5',
    blockType: 'mssql',
    label: 'SQL Server results to Sim table',
    prompt:
        'Create a scheduled workflow that runs a Microsoft SQL Server query for the latest records and writes each row into a Sim table, so the data is available for downstream blocks without a live database call.',
    iconId: 'brand/microsoft-sql-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mssql-6',
    blockType: 'mssql',
    label: 'SQL Server threshold breach alert',
    prompt:
        'Build a scheduled workflow that queries a Microsoft SQL Server count or aggregate, compares it to a threshold, and posts a Slack alert only when the value crosses the limit so the team hears about problems early.',
    iconId: 'brand/microsoft-sql-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mssql-7',
    blockType: 'mssql',
    label: 'Log form submissions to SQL Server',
    prompt:
        'Create a workflow that takes an incoming payload, validates the fields, and inserts a new row into a Microsoft SQL Server table so every submission is durably recorded.',
    iconId: 'brand/microsoft-sql-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mysql-0',
    blockType: 'mysql',
    label: 'Ask your MySQL database in plain English',
    prompt:
        'Build a workflow that takes a plain-English question, has an agent translate it into a MySQL SELECT against the known schema, runs the query, and returns the rows as a readable answer.',
    iconId: 'emcn/search',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mysql-1',
    blockType: 'mysql',
    label: 'Daily MySQL metrics report to Slack',
    prompt:
        'Create a scheduled workflow that runs a MySQL query for yesterday’s key metrics, has an agent summarize the rows into a short update, and posts the digest to a Slack channel every morning.',
    iconId: 'emcn/clipboard-list',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mysql-2',
    blockType: 'mysql',
    label: 'Document a MySQL schema',
    prompt:
        'Build a workflow that introspects a MySQL database schema, has an agent write plain-English descriptions of each table and column, and saves the generated data dictionary as a file.',
    iconId: 'emcn/table',
    modules: <String>['files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mysql-3',
    blockType: 'mysql',
    label: 'Sync records from a Sim table into MySQL',
    prompt:
        'Create a workflow that reads rows from a Sim table and upserts each one into a MySQL table — updating the row when a matching key exists and inserting it otherwise — so the two stay in sync.',
    iconId: 'emcn/database',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mysql-4',
    blockType: 'mysql',
    label: 'Nightly MySQL data-quality audit',
    prompt:
        'Build a scheduled workflow that runs MySQL queries checking for nulls, duplicates, and orphaned foreign keys, has an agent describe any issues found, and alerts the team in Slack when the counts are non-zero.',
    iconId: 'emcn/search',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mysql-5',
    blockType: 'mysql',
    label: 'Scheduled MySQL cleanup job',
    prompt:
        'Create a scheduled workflow that deletes stale or soft-deleted rows from a MySQL table older than a retention window, reports the row count removed, and keeps the table lean over time.',
    iconId: 'emcn/wrench',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mysql-6',
    blockType: 'mysql',
    label: 'Capture incoming records into MySQL',
    prompt:
        'Build a workflow that takes an incoming payload, validates the fields with an agent, and inserts a new row into the right MySQL table so submissions are persisted for later querying.',
    iconId: 'emcn/database',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'mysql-7',
    blockType: 'mysql',
    label: 'Export a MySQL query result to a file',
    prompt:
        'Create a scheduled workflow that runs a MySQL query for a snapshot of a table, writes the returned rows to a file, and keeps a dated export available for backups and downstream analysis.',
    iconId: 'emcn/server',
    modules: <String>['scheduled', 'files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'neo4j-0',
    blockType: 'neo4j',
    label: 'Neo4j relationship exporter',
    prompt:
        'Build a workflow that queries Neo4j for a chosen entity graph, writes the nodes and edges to a structured JSON adjacency file, and shares the file link for a downstream tool to visualize.',
    iconId: 'brand/neo4j-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'neo4j-1',
    blockType: 'neo4j',
    label: 'Neo4j fraud-ring detector',
    prompt:
        'Create a scheduled workflow that queries Neo4j for suspicious connection patterns — shared devices, overlapping addresses — writes risk-scored clusters to a fraud table, and pings Slack.',
    iconId: 'brand/neo4j-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'neo4j-2',
    blockType: 'neo4j',
    label: 'Neo4j org-chart sync',
    prompt:
        'Build a workflow that pulls Workday or Rippling worker data, upserts employees and reporting relationships into Neo4j, and exposes a queryable org graph for downstream tools.',
    iconId: 'brand/neo4j-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'neo4j-3',
    blockType: 'neo4j',
    label: 'Neo4j knowledge-graph builder',
    prompt:
        'Create a workflow that processes documents from a knowledge base, extracts entities and relationships with an agent, and writes the graph into Neo4j for cross-document insights.',
    iconId: 'brand/neo4j-icon',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'neo4j-4',
    blockType: 'neo4j',
    label: 'Neo4j recommendation engine',
    prompt:
        'Build a workflow that runs Neo4j graph algorithms — collaborative filtering, PageRank — on product-purchase data and writes per-user recommendations to a personalization table.',
    iconId: 'brand/neo4j-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'neo4j-5',
    blockType: 'neo4j',
    label: 'Neo4j data lineage tracker',
    prompt:
        'Create a workflow that ingests dbt manifest metadata into Neo4j, tracks lineage across tables and pipelines, and queries impact when a source schema changes.',
    iconId: 'brand/neo4j-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'neo4j-6',
    blockType: 'neo4j',
    label: 'Neo4j natural-language graph explorer',
    prompt:
        'Build a chat agent that introspects the Neo4j schema, translates plain-English questions like “which customers share a support agent with churned accounts?” into Cypher queries, runs them, and returns a readable answer with the matching nodes.',
    iconId: 'brand/neo4j-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'netsuite-0',
    blockType: 'netsuite',
    label: 'Synchronize NetSuite customers',
    prompt:
        'Build a scheduled workflow that queries customers changed since the last run, upserts them into the destination CRM by external ID, and stores the new NetSuite server time for the next sync.',
    iconId: 'brand/net-suite-icon',
    modules: <String>['scheduled', 'tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'netsuite-1',
    blockType: 'netsuite',
    label: 'Process NetSuite sales orders',
    prompt:
        'Create a workflow that looks up an approved NetSuite sales order, validates its lines, transforms it into an item fulfillment, and reports the completed transformation status.',
    iconId: 'brand/net-suite-icon',
    modules: <String>['workflows'],
  ),
  SuggestionTemplate(
    id: 'netsuite-2',
    blockType: 'netsuite',
    label: 'Reconcile vendors and purchase orders',
    prompt:
        'Build a scheduled workflow that runs SuiteQL to compare open purchase orders with vendor records, flags missing or mismatched vendor details, and writes the reconciliation report to a table.',
    iconId: 'brand/net-suite-icon',
    modules: <String>['scheduled', 'tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'netsuite-3',
    blockType: 'netsuite',
    label: 'Monitor NetSuite inventory',
    prompt:
        'Create a scheduled workflow that uses SuiteQL to find inventory items below reorder point, enriches each item with its NetSuite record, and sends an operations digest.',
    iconId: 'brand/net-suite-icon',
    modules: <String>['scheduled', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'netsuite-4',
    blockType: 'netsuite',
    label: 'Generate SuiteQL finance reports',
    prompt:
        'Build a workflow that accepts a reporting period, executes a bounded SuiteQL financial query with a stable ORDER BY clause, and stores the returned page in a table for review.',
    iconId: 'brand/net-suite-icon',
    modules: <String>['tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'netsuite-5',
    blockType: 'netsuite',
    label: 'Export SuiteAnalytics datasets',
    prompt:
        'Create a scheduled workflow that lists available NetSuite SuiteAnalytics datasets, executes the selected dataset one page at a time, and writes each export page to a file.',
    iconId: 'brand/net-suite-icon',
    modules: <String>['scheduled', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'netsuite-6',
    blockType: 'netsuite',
    label: 'Import records with async batches',
    prompt:
        'Build a workflow that validates up to 100 homogeneous NetSuite records against metadata, submits an asynchronous batch upsert with an idempotency key, lists its tasks, checks each task, and retrieves every completed result.',
    iconId: 'brand/net-suite-icon',
    modules: <String>['workflows'],
  ),
  SuggestionTemplate(
    id: 'new_relic-0',
    blockType: 'new_relic',
    label: 'New Relic health report',
    prompt:
        'Create a scheduled daily workflow that runs NRQL queries against New Relic for error rate, latency percentiles, and throughput, logs the results to a table for trend tracking, and Slacks a morning summary highlighting any degradations.',
    iconId: 'brand/new-relic-icon',
    modules: <String>['tables', 'scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'new_relic-1',
    blockType: 'new_relic',
    label: 'New Relic deployment tracker',
    prompt:
        'Build a workflow that fires after each production release, records a New Relic deployment change event for the affected entity, and posts a Slack note linking the deployment to the dashboard for the on-call engineer.',
    iconId: 'brand/new-relic-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'new_relic-2',
    blockType: 'new_relic',
    label: 'New Relic anomaly investigator',
    prompt:
        'Create a workflow triggered by an alert that runs targeted NRQL queries to pull the surrounding error and latency data, searches related New Relic entities for blast radius, summarizes likely causes, and opens a Linear ticket.',
    iconId: 'brand/new-relic-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'new_relic-3',
    blockType: 'new_relic',
    label: 'New Relic entity inventory',
    prompt:
        'Build a scheduled weekly workflow that searches New Relic for all monitored entities, fetches details for each, logs them into an inventory table, and Slacks a diff of newly added or removed services.',
    iconId: 'brand/new-relic-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'new_relic-4',
    blockType: 'new_relic',
    label: 'New Relic SLO weekly review',
    prompt:
        'Create a scheduled weekly workflow that runs NRQL queries to compute error budget burn for each service, writes a narrative review file for the SRE team, and links the supporting dashboards.',
    iconId: 'brand/new-relic-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'new_relic-5',
    blockType: 'new_relic',
    label: 'New Relic cost-by-service breakdown',
    prompt:
        'Build a scheduled monthly workflow that runs NRQL queries to attribute data ingest and compute to each New Relic entity, writes a per-team cost breakdown to a table, and emails finance the services trending over budget.',
    iconId: 'brand/new-relic-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'new_relic-6',
    blockType: 'new_relic',
    label: 'New Relic incident war-room kickoff',
    prompt:
        'Create a workflow triggered by a PagerDuty incident that runs NRQL queries for the impacted service, pulls the latest deployment change event from New Relic, and posts a war-room summary with golden-signal charts to the incident Slack channel.',
    iconId: 'brand/new-relic-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'notion-0',
    blockType: 'notion',
    label: 'Notion customer support bot',
    prompt:
        'Create a knowledge base and connect it to my Notion or Google Docs so it stays synced with my product documentation automatically. Then build an agent that answers customer questions using it with sourced citations and deploy it as a chat endpoint.',
    iconId: 'emcn/send',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
    providerId: 'notion',
  ),
  SuggestionTemplate(
    id: 'notion-1',
    blockType: 'notion',
    label: 'Notion knowledge search',
    prompt:
        'Create a knowledge base connected to my Notion workspace so all pages, databases, meeting notes, and wikis are automatically synced and searchable. Then build an agent I can ask things like "what\'s our refund policy?" or "what was decided in the Q3 planning doc?" and get instant answers with page links.',
    iconId: 'brand/notion-icon',
    modules: <String>['knowledge-base', 'agent'],
    providerId: 'notion',
  ),
  SuggestionTemplate(
    id: 'notion-2',
    blockType: 'notion',
    label: 'Notify your team from Notion',
    prompt:
        'Build a workflow that watches Notion for new or updated pages and automatically posts a Slack message so your team stays aligned without manual check-ins.',
    iconId: 'brand/notion-icon',
    modules: <String>['agent', 'workflows'],
    featured: true,
    providerId: 'notion',
  ),
  SuggestionTemplate(
    id: 'notion-3',
    blockType: 'notion',
    label: 'Notion meeting-notes capture',
    prompt:
        'Build a workflow that runs after a Google Meet call, fetches the transcript, and creates a structured Notion page under the right project with attendees, decisions, and action items.',
    iconId: 'brand/notion-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'notion',
  ),
  SuggestionTemplate(
    id: 'notion-4',
    blockType: 'notion',
    label: 'Notion CRM enrichment',
    prompt:
        'Create a workflow that watches a Notion database of companies, researches each new entry for funding, headcount, and industry, and appends the enriched fields back to the Notion page so the pipeline stays current.',
    iconId: 'brand/notion-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'notion',
  ),
  SuggestionTemplate(
    id: 'notion-5',
    blockType: 'notion',
    label: 'Notion content calendar publisher',
    prompt:
        'Build a scheduled workflow that queries a Notion content-calendar database for posts marked ready today, formats each one, and publishes it to the blog while updating the Notion page status to published.',
    iconId: 'brand/notion-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'notion',
  ),
  SuggestionTemplate(
    id: 'notion-6',
    blockType: 'notion',
    label: 'Notion weekly digest builder',
    prompt:
        'Create a scheduled weekly workflow that queries a Notion project database for items completed this week, appends a summary section to a Notion review page, and posts the highlights to Slack for the team.',
    iconId: 'brand/notion-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'notion',
  ),
  SuggestionTemplate(
    id: 'obsidian-0',
    blockType: 'obsidian',
    label: 'Obsidian daily journal agent',
    prompt:
        'Build a workflow that pulls calendar events, completed tasks, and journal prompts, and generates a daily Obsidian note draft for the user to review and annotate.',
    iconId: 'brand/obsidian-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'obsidian-1',
    blockType: 'obsidian',
    label: 'Obsidian backlink builder',
    prompt:
        'Create a workflow that processes new Obsidian notes, identifies entities and concepts that should be wikilinks, and rewrites the note with proper backlinks plus a hub note for new tags.',
    iconId: 'brand/obsidian-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'obsidian-2',
    blockType: 'obsidian',
    label: 'Obsidian web clipper',
    prompt:
        'Build a workflow that accepts a URL from a form, scrapes the page with Firecrawl, summarizes with an agent, and writes the clip as a new Obsidian note with source metadata.',
    iconId: 'brand/obsidian-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'obsidian-3',
    blockType: 'obsidian',
    label: 'Obsidian knowledge-base sync',
    prompt:
        'Create a workflow that mirrors an Obsidian vault into a Sim knowledge base so an agent can answer questions over personal notes with citations.',
    iconId: 'brand/obsidian-icon',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'obsidian-4',
    blockType: 'obsidian',
    label: 'Obsidian smart review',
    prompt:
        'Build a scheduled weekly workflow that surfaces stale Obsidian notes due for spaced-repetition review, scores their freshness, and writes a review queue note for the user.',
    iconId: 'brand/obsidian-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'obsidian-5',
    blockType: 'obsidian',
    label: 'Obsidian meeting-note autopopulator',
    prompt:
        'Create a workflow that runs after a Google Meet meeting, fetches the transcript, and appends a structured meeting note to an Obsidian vault under the right project folder.',
    iconId: 'brand/obsidian-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'obsidian-6',
    blockType: 'obsidian',
    label: 'Obsidian reading-list digester',
    prompt:
        'Build a scheduled workflow that reads the links saved in an Obsidian "to read" note, summarizes each article with an agent, and appends the key takeaways back into the vault as individual literature notes with source links.',
    iconId: 'brand/obsidian-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'okta-0',
    blockType: 'okta',
    label: 'Okta quarterly access review',
    prompt:
        'Build a scheduled quarterly workflow that pulls Okta group memberships per app, posts an attestation thread to each owner in Slack, captures confirmations, and writes the audit log to a compliance table.',
    iconId: 'brand/okta-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'okta-1',
    blockType: 'okta',
    label: 'Okta orphan-account sweeper',
    prompt:
        'Create a scheduled workflow that compares Okta users against HRIS data, finds accounts for departed employees, disables them, and writes the sweep log to an audit table.',
    iconId: 'brand/okta-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'okta-2',
    blockType: 'okta',
    label: 'Okta new-hire provisioning',
    prompt:
        'Build a workflow that polls Workday for new hires, creates the matching Okta user, adds them to the right groups for their role, and emails IT a provisioning summary.',
    iconId: 'brand/okta-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'okta-3',
    blockType: 'okta',
    label: 'Okta compromised-account responder',
    prompt:
        'Create a workflow triggered by a CrowdStrike detection on a user that suspends the matching Okta account, resets their password, and pings the security Slack channel with the action taken.',
    iconId: 'brand/okta-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'okta-4',
    blockType: 'okta',
    label: 'Okta access-group provisioner',
    prompt:
        'Build a workflow that reads an access-request table, creates the Okta group if it is missing, adds the approved users to it, and writes the grant record back to the table.',
    iconId: 'brand/okta-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'okta-5',
    blockType: 'okta',
    label: 'Okta SSO group sync',
    prompt:
        'Create a scheduled workflow that mirrors org structure from Workday into Okta groups, ensuring group memberships stay in sync as employees change roles.',
    iconId: 'brand/okta-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'okta-6',
    blockType: 'okta',
    label: 'Okta group membership audit',
    prompt:
        'Build a scheduled monthly workflow that lists every Okta group and its members, flags privileged groups with unexpected membership, and writes a review report for the security team.',
    iconId: 'brand/okta-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'onedrive-0',
    blockType: 'onedrive',
    label: 'OneDrive contract intake',
    prompt:
        'Create a scheduled workflow that polls a OneDrive intake folder for new contract PDFs, extracts clauses with Reducto, writes the structured terms to a table, and pings legal in Teams.',
    iconId: 'brand/microsoft-one-drive-icon',
    modules: <String>['scheduled', 'files', 'tables', 'agent', 'workflows'],
    providerId: 'onedrive',
  ),
  SuggestionTemplate(
    id: 'onedrive-1',
    blockType: 'onedrive',
    label: 'OneDrive sharing audit',
    prompt:
        'Build a scheduled weekly workflow that lists OneDrive files shared externally, flags ones above a sensitivity score, and writes a security review report.',
    iconId: 'brand/microsoft-one-drive-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'onedrive',
  ),
  SuggestionTemplate(
    id: 'onedrive-2',
    blockType: 'onedrive',
    label: 'OneDrive to knowledge base sync',
    prompt:
        'Create a workflow that mirrors OneDrive folders into a knowledge base, chunks and embeds new content on change, and removes deleted files so retrieval stays accurate.',
    iconId: 'brand/microsoft-one-drive-icon',
    modules: <String>['knowledge-base', 'files', 'agent', 'workflows'],
    providerId: 'onedrive',
  ),
  SuggestionTemplate(
    id: 'onedrive-3',
    blockType: 'onedrive',
    label: 'OneDrive backup verifier',
    prompt:
        'Build a scheduled workflow that verifies OneDrive backups by sampling files and comparing checksums against the originating SharePoint copy, writing the report to an SRE table.',
    iconId: 'brand/microsoft-one-drive-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'onedrive',
  ),
  SuggestionTemplate(
    id: 'onedrive-4',
    blockType: 'onedrive',
    label: 'OneDrive retention cleaner',
    prompt:
        'Create a scheduled workflow that finds OneDrive files older than the retention horizon, requires manager approval through Teams, and archives or deletes per the policy.',
    iconId: 'brand/microsoft-one-drive-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'onedrive',
  ),
  SuggestionTemplate(
    id: 'onedrive-5',
    blockType: 'onedrive',
    label: 'OneDrive Excel-pipeline opener',
    prompt:
        'Build a scheduled workflow that polls OneDrive for new Excel data drops, normalizes each, writes to a downstream table, and emails the analyst that the latest file is ready.',
    iconId: 'brand/microsoft-one-drive-icon',
    modules: <String>['scheduled', 'files', 'tables', 'agent', 'workflows'],
    providerId: 'onedrive',
  ),
  SuggestionTemplate(
    id: 'onedrive-6',
    blockType: 'onedrive',
    label: 'OneDrive new-hire kit deployer',
    prompt:
        'Create a workflow triggered by a Workday new hire that creates a OneDrive new-hire folder, uploads the standard onboarding documents into it, and writes the folder link into the onboarding tracker.',
    iconId: 'brand/microsoft-one-drive-icon',
    modules: <String>['files', 'agent', 'workflows'],
    providerId: 'onedrive',
  ),
  SuggestionTemplate(
    id: 'onepassword-0',
    blockType: 'onepassword',
    label: '1Password vault audit',
    prompt:
        'Build a scheduled monthly workflow that scans 1Password vaults for weak or reused passwords, expired items, and unused secrets, and writes a remediation queue.',
    iconId: 'brand/one-password-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'onepassword-1',
    blockType: 'onepassword',
    label: '1Password offboarding sweep',
    prompt:
        'Create a workflow that on a Workday termination rotates the shared 1Password secrets the departing employee had access to, updates the affected items, and writes the action log.',
    iconId: 'brand/one-password-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'onepassword-2',
    blockType: 'onepassword',
    label: '1Password access-review automator',
    prompt:
        'Build a scheduled quarterly workflow that inventories 1Password items per vault, requires owner re-attestation in Slack, and writes the audit log to a compliance table.',
    iconId: 'brand/one-password-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'onepassword-3',
    blockType: 'onepassword',
    label: '1Password secret rotation watcher',
    prompt:
        'Create a scheduled workflow that finds 1Password items older than the rotation policy, opens a Linear ticket per item to rotate, and writes the rotation status back.',
    iconId: 'brand/one-password-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'onepassword-4',
    blockType: 'onepassword',
    label: '1Password onboarding kit',
    prompt:
        'Build a workflow that when a new hire is provisioned creates their starter 1Password items based on role and team, and writes the access record to the onboarding table.',
    iconId: 'brand/one-password-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'onepassword-5',
    blockType: 'onepassword',
    label: '1Password Slack secret-share guard',
    prompt:
        'Create a workflow that monitors Slack for accidental secret sharing, redacts the message, and posts a polite reminder to use 1Password Secret Sharing instead.',
    iconId: 'brand/one-password-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'onepassword-6',
    blockType: 'onepassword',
    label: '1Password compliance reporter',
    prompt:
        'Build a scheduled workflow that produces a 1Password compliance report — item counts, ages, and categories per vault — and writes the report file for auditors.',
    iconId: 'brand/one-password-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'oracle_fusion_financials-0',
    blockType: 'oracle_fusion_financials',
    label: 'Payables invoice review',
    prompt:
        'Build a scheduled workflow that lists a bounded page of Oracle Fusion payables invoices, reads the lines of selected invoices, and summarizes approval status, validation status, amounts, and supplier details.',
    iconId: 'brand/oracle-icon',
    modules: <String>['workflows'],
    providerId: 'oracle-fusion',
  ),
  SuggestionTemplate(
    id: 'oracle_fusion_financials-1',
    blockType: 'oracle_fusion_financials',
    label: 'Payables payment report',
    prompt:
        'Build a workflow that lists Oracle Fusion payables payments for a documented date filter and reports payment amounts, currencies, methods, and reconciliation flags.',
    iconId: 'brand/oracle-icon',
    modules: <String>['workflows'],
    providerId: 'oracle-fusion',
  ),
  SuggestionTemplate(
    id: 'oracle_fusion_financials-2',
    blockType: 'oracle_fusion_financials',
    label: 'Receivables invoice creation',
    prompt:
        'Build a workflow that creates an Oracle Fusion receivables invoice from approved billing details and line items, then reads the created invoice to report its number, balance, and status.',
    iconId: 'brand/oracle-icon',
    modules: <String>['workflows'],
    providerId: 'oracle-fusion',
  ),
  SuggestionTemplate(
    id: 'oracle_fusion_financials-3',
    blockType: 'oracle_fusion_financials',
    label: 'Receipt application',
    prompt:
        'Build a workflow that reads a receivables invoice and its installments, creates a standard receipt from approved payment details, and applies an explicitly supplied amount to the selected installment.',
    iconId: 'brand/oracle-icon',
    modules: <String>['workflows'],
    providerId: 'oracle-fusion',
  ),
  SuggestionTemplate(
    id: 'oracle_fusion_financials-4',
    blockType: 'oracle_fusion_financials',
    label: 'Credit memo creation',
    prompt:
        'Build a workflow that creates an Oracle Fusion receivables credit memo from approved customer, transaction, and line details, then reads the resulting memo.',
    iconId: 'brand/oracle-icon',
    modules: <String>['workflows'],
    providerId: 'oracle-fusion',
  ),
  SuggestionTemplate(
    id: 'oracle_fusion_financials-5',
    blockType: 'oracle_fusion_financials',
    label: 'Expense report submission',
    prompt:
        'Build a workflow that creates an Oracle Fusion expense report, adds validated expense lines with employee and business-unit identifiers, submits the report, and checks whether Oracle accepted submission without errors.',
    iconId: 'brand/oracle-icon',
    modules: <String>['workflows'],
    providerId: 'oracle-fusion',
  ),
  SuggestionTemplate(
    id: 'oracle_fusion_financials-6',
    blockType: 'oracle_fusion_financials',
    label: 'Ledger balance report',
    prompt:
        'Build a workflow that lists Oracle Fusion ledgers and queries ledger balances using a documented finder, then summarizes the returned balance amounts for the selected accounting period.',
    iconId: 'brand/oracle-icon',
    modules: <String>['workflows'],
    providerId: 'oracle-fusion',
  ),
  SuggestionTemplate(
    id: 'oracledb-0',
    blockType: 'oracledb',
    label: 'Ask Oracle in English',
    prompt:
        'Build a workflow that accepts a natural-language question, introspects the relevant Oracle schema, has an agent produce a bounded SELECT with named binds, runs it, and returns a readable answer with the supporting rows.',
    iconId: 'brand/oracle-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'oracledb-1',
    blockType: 'oracledb',
    label: 'Oracle KPI digest',
    prompt:
        'Create a scheduled workflow that queries key business metrics from Oracle Database each morning, has an agent summarize changes and anomalies, and posts the digest to Slack.',
    iconId: 'brand/oracle-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'oracledb-2',
    blockType: 'oracledb',
    label: 'Document Oracle schema',
    prompt:
        'Build a workflow that introspects an accessible Oracle schema, then has an agent turn its tables, columns, keys, and indexes into plain-English database documentation.',
    iconId: 'brand/oracle-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'oracledb-3',
    blockType: 'oracledb',
    label: 'Merge Oracle records',
    prompt:
        'Create a workflow that validates incoming records and executes an Oracle MERGE so matching rows are updated and new rows are inserted without a read-before-write race.',
    iconId: 'brand/oracle-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'oracledb-4',
    blockType: 'oracledb',
    label: 'Clean stale Oracle data',
    prompt:
        'Build a scheduled workflow that previews rows older than a retention cutoff, deletes only the matching Oracle records, and reports the affected row count.',
    iconId: 'brand/oracle-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'oracledb-5',
    blockType: 'oracledb',
    label: 'Sync Oracle to Sim',
    prompt:
        'Create a scheduled workflow that queries the latest Oracle records and writes each normalized row into a Sim table for downstream workflows and analysis.',
    iconId: 'brand/oracle-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'oracledb-6',
    blockType: 'oracledb',
    label: 'Alert on Oracle thresholds',
    prompt:
        'Build a scheduled workflow that runs an Oracle aggregate query, compares the result with a threshold, and sends a Slack alert only when the limit is crossed.',
    iconId: 'brand/oracle-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'oracledb-7',
    blockType: 'oracledb',
    label: 'Log webhooks in Oracle',
    prompt:
        'Create a workflow triggered by an incoming webhook that validates and reshapes the payload, then inserts one bound row into an Oracle audit or event table.',
    iconId: 'brand/oracle-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'otter-0',
    blockType: 'otter',
    label: 'Otter meeting recap to Slack',
    prompt:
        'Build a workflow that runs when an Otter conversation finishes processing, turns its summary, action items, and insights into a short recap, and posts it to the team Slack channel.',
    iconId: 'brand/otter-icon',
    modules: <String>['agent', 'workflows'],
    featured: true,
  ),
  SuggestionTemplate(
    id: 'otter-1',
    blockType: 'otter',
    label: 'Otter sales call to CRM',
    prompt:
        'Create a workflow triggered by an Otter conversation shared to the sales calls channel that matches calendar guests to HubSpot contacts and logs the meeting summary and next steps on the deal.',
    iconId: 'brand/otter-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'otter-2',
    blockType: 'otter',
    label: 'Otter action items to Linear',
    prompt:
        'Build a workflow that reads the action items of each completed Otter conversation and creates a Linear issue for every item, assigned to the matching teammate by email.',
    iconId: 'brand/otter-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'otter-3',
    blockType: 'otter',
    label: 'Otter transcripts to knowledge base',
    prompt:
        'Create a scheduled workflow that lists new Otter conversations each day, fetches their transcripts and outlines, and adds them to a knowledge base so agents can answer questions about past meetings.',
    iconId: 'brand/otter-icon',
    modules: <String>['scheduled', 'knowledge-base', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'otter-4',
    blockType: 'otter',
    label: 'Otter dialer call import',
    prompt:
        'Build a workflow that takes call recording URLs from a dialer export in a table and imports each one into Otter as a named conversation, recording the import status back in the table.',
    iconId: 'brand/otter-icon',
    modules: <String>['tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'otter-5',
    blockType: 'otter',
    label: 'Otter customer insight log',
    prompt:
        'Create a workflow that runs on every completed Otter customer call, extracts pain points, objections, and feature requests from the insights and transcript, and appends them to a research table.',
    iconId: 'brand/otter-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'otter-6',
    blockType: 'otter',
    label: 'Otter weekly meeting digest',
    prompt:
        'Build a scheduled weekly workflow that lists the week’s Otter conversations in a channel, summarizes recurring themes and decisions from their outlines, and emails the digest to the team.',
    iconId: 'brand/otter-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'outlook-0',
    blockType: 'outlook',
    label: 'Outlook auto-responder',
    prompt:
        'Build a workflow that monitors my Outlook inbox, drafts a contextual reply for every email that needs a response using my recent threads as tone reference, and saves each reply as an Outlook draft for me to review and send.',
    iconId: 'brand/outlook-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'outlook',
  ),
  SuggestionTemplate(
    id: 'outlook-1',
    blockType: 'outlook',
    label: 'Outlook customer escalation to Zendesk',
    prompt:
        'Create a workflow that reads new Outlook emails from customers, classifies whether each one is a support issue, and when it is, creates a Zendesk ticket with the email body, attachments, and contact details, then replies from Outlook with the ticket number.',
    iconId: 'brand/outlook-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'outlook',
  ),
  SuggestionTemplate(
    id: 'outlook-2',
    blockType: 'outlook',
    label: 'Outlook executive triage',
    prompt:
        'Build a scheduled workflow that scans Outlook every hour, ranks new emails by urgency, summarizes the top items, and posts a prioritized digest to a Slack channel so executives can act without opening the inbox.',
    iconId: 'brand/outlook-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'outlook',
  ),
  SuggestionTemplate(
    id: 'outlook-3',
    blockType: 'outlook',
    label: 'Outlook invoice extractor',
    prompt:
        'Build a workflow that monitors Outlook for invoice attachments, extracts vendor, amount, due date, and line items from each PDF, and logs the results to a tracking table while moving the original email to an Invoices folder.',
    iconId: 'brand/outlook-icon',
    modules: <String>['files', 'tables', 'agent', 'workflows'],
    providerId: 'outlook',
  ),
  SuggestionTemplate(
    id: 'outlook-4',
    blockType: 'outlook',
    label: 'Outlook follow-up reminder',
    prompt:
        'Create a workflow that scans Outlook for sent emails awaiting a reply older than three business days, drafts a polite follow-up email per thread, and saves each one as a draft in Outlook ready to send.',
    iconId: 'brand/outlook-icon',
    modules: <String>['agent', 'scheduled', 'workflows'],
    providerId: 'outlook',
  ),
  SuggestionTemplate(
    id: 'outlook-5',
    blockType: 'outlook',
    label: 'Outlook to JSM ticket router',
    prompt:
        'Build a workflow that reads support requests arriving in a shared Outlook mailbox, classifies the request type, and creates a Jira Service Management request in the correct service desk with the right request type, then replies from Outlook with the JSM portal link.',
    iconId: 'brand/outlook-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'outlook',
  ),
  SuggestionTemplate(
    id: 'outlook-6',
    blockType: 'outlook',
    label: 'Outlook newsletter clipper',
    prompt:
        'Create a workflow that reads newsletters arriving in Outlook, summarizes each one into key takeaways, and appends the digest to a daily Notion page so the inbox stays clean and the insights stay searchable.',
    iconId: 'brand/outlook-icon',
    modules: <String>['agent', 'scheduled', 'workflows'],
    providerId: 'outlook',
  ),
  SuggestionTemplate(
    id: 'outlook-7',
    blockType: 'outlook',
    label: 'Outlook contract clause flagger',
    prompt:
        'Build a workflow that scans Outlook for inbound contracts and amendments, extracts key clauses (payment terms, liability, termination, renewal), flags deviations from my standard terms, and replies internally with a summary and red-flag list.',
    iconId: 'brand/outlook-icon',
    modules: <String>['files', 'agent', 'workflows'],
    providerId: 'outlook',
  ),
  SuggestionTemplate(
    id: 'outlook-8',
    blockType: 'outlook',
    label: 'Outlook meeting scheduler',
    prompt:
        'Build a workflow that reads emails requesting a meeting, checks my Outlook calendar for the requested window, creates an Outlook calendar event with the sender as an attendee and a Teams link, and replies from Outlook confirming the time.',
    iconId: 'brand/outlook-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'outlook',
  ),
  SuggestionTemplate(
    id: 'outlook-9',
    blockType: 'outlook',
    label: 'Outlook daily agenda digest',
    prompt:
        'Create a scheduled workflow that lists my Outlook calendar events for the day each morning, summarizes each meeting with its attendees and join link, and posts the agenda to a Slack DM before my first meeting.',
    iconId: 'brand/outlook-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'outlook',
  ),
  SuggestionTemplate(
    id: 'outlook-10',
    blockType: 'outlook',
    label: 'Outlook invite auto-responder',
    prompt:
        'Build a workflow that reviews new Outlook meeting invitations, checks my calendar for conflicts in that time window, and accepts, tentatively accepts, or declines each invite with a short note to the organizer explaining the decision.',
    iconId: 'brand/outlook-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'outlook',
  ),
  SuggestionTemplate(
    id: 'pagerduty-0',
    blockType: 'pagerduty',
    label: 'PagerDuty incident war room',
    prompt:
        'Build a scheduled workflow that polls PagerDuty for new severity-1 incidents, opens a Slack war-room channel, invites responders, posts the incident summary, and updates the channel topic with status.',
    iconId: 'brand/pager-duty-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'pagerduty-1',
    blockType: 'pagerduty',
    label: 'PagerDuty on-call digest',
    prompt:
        'Create a scheduled daily workflow that summarizes the past 24 hours of PagerDuty incidents, MTTR, and on-call load by responder, and posts a Slack digest to the SRE channel.',
    iconId: 'brand/pager-duty-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'pagerduty-2',
    blockType: 'pagerduty',
    label: 'PagerDuty escalation auditor',
    prompt:
        'Build a scheduled weekly workflow that audits PagerDuty escalation policies, on-call schedules, and gaps in coverage, and writes a remediation backlog to a tracking table.',
    iconId: 'brand/pager-duty-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'pagerduty-3',
    blockType: 'pagerduty',
    label: 'PagerDuty postmortem starter',
    prompt:
        'Create a scheduled workflow that polls PagerDuty for newly resolved incidents and opens a postmortem doc for each with the timeline, responders, and Slack thread linked, ready for the team to fill in root cause.',
    iconId: 'brand/pager-duty-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'pagerduty-4',
    blockType: 'pagerduty',
    label: 'PagerDuty auto-triage enricher',
    prompt:
        'Build a scheduled workflow that polls PagerDuty for new incidents, pulls the affected service details, queries recent logs and the latest deploy, and posts an enriched triage summary with likely cause back as an incident note for the responder.',
    iconId: 'brand/pager-duty-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'pagerduty-5',
    blockType: 'pagerduty',
    label: 'PagerDuty customer-impact notifier',
    prompt:
        'Create a scheduled workflow that polls PagerDuty for incidents on customer-facing services, looks up affected accounts in Salesforce, and drafts a status-page update plus a Slack alert to the customer success team for high-impact outages.',
    iconId: 'brand/pager-duty-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'pagerduty-6',
    blockType: 'pagerduty',
    label: 'PagerDuty alert-to-ticket bridge',
    prompt:
        'Build a workflow that creates a PagerDuty incident from inbound monitoring alerts, opens a matching Linear issue with the same severity and links the two, and logs the pairing in a table so engineering can track alert-to-fix time.',
    iconId: 'brand/pager-duty-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'parallel_ai-0',
    blockType: 'parallel_ai',
    label: 'Parallel AI account research agent',
    prompt:
        'Build a workflow that takes a company name, runs Parallel AI deep research for recent funding, leadership changes, and product launches, and writes a structured account brief with citations back to the matching CRM record.',
    iconId: 'brand/parallel-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'parallel_ai-1',
    blockType: 'parallel_ai',
    label: 'Parallel AI competitor monitor',
    prompt:
        'Create a scheduled workflow that uses Parallel AI search to find new announcements from a list of competitors, extracts the key details from each source URL, and posts a cited digest to Slack for the product team.',
    iconId: 'brand/parallel-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'parallel_ai-2',
    blockType: 'parallel_ai',
    label: 'Parallel AI URL fact extractor',
    prompt:
        'Build a workflow that reads a table of source URLs, uses Parallel AI extract to pull the structured facts requested for each page, and writes the normalized results back to the table for review.',
    iconId: 'brand/parallel-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'parallel_ai-3',
    blockType: 'parallel_ai',
    label: 'Parallel AI market landscape report',
    prompt:
        'Create a workflow that runs Parallel AI deep research on a market category, synthesizes the players, pricing, and trends into a Markdown report file, and shares the link with the strategy team.',
    iconId: 'brand/parallel-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'parallel_ai-4',
    blockType: 'parallel_ai',
    label: 'Parallel AI lead enrichment pipeline',
    prompt:
        'Build a workflow that runs Parallel AI search and extract on each new inbound lead to find company size, industry, and tech stack, scores fit against the ICP, and updates the lead record with the enriched profile.',
    iconId: 'brand/parallel-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'parallel_ai-5',
    blockType: 'parallel_ai',
    label: 'Parallel AI due-diligence brief',
    prompt:
        'Create a workflow that runs Parallel AI deep research on a target company for litigation, leadership, and financial signals, extracts supporting detail from each cited source, and writes a due-diligence brief file for the deal team.',
    iconId: 'brand/parallel-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'parallel_ai-6',
    blockType: 'parallel_ai',
    label: 'Parallel AI daily topic digest',
    prompt:
        'Build a scheduled daily workflow that uses Parallel AI search across the topics a team follows, extracts the key facts from the top results, and emails a concise cited digest each morning.',
    iconId: 'brand/parallel-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'peopledatalabs-0',
    blockType: 'peopledatalabs',
    label: 'PDL person enricher',
    prompt:
        'Build a workflow that watches CRM contacts, enriches each via People Data Labs with role, seniority, and company signals, and writes the enriched data back.',
    iconId: 'brand/people-data-labs-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'peopledatalabs-1',
    blockType: 'peopledatalabs',
    label: 'PDL company enricher',
    prompt:
        'Create a workflow that takes a list of company domains, runs People Data Labs company-search, and writes firmographics, employee count, and tech stack into a tables-based research base.',
    iconId: 'brand/people-data-labs-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'peopledatalabs-2',
    blockType: 'peopledatalabs',
    label: 'PDL ICP scorer',
    prompt:
        'Build a workflow that scores inbound leads against the ICP using People Data Labs enrichment fields, routes high-fit leads to sales, and writes the score back to the CRM.',
    iconId: 'brand/people-data-labs-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'peopledatalabs-3',
    blockType: 'peopledatalabs',
    label: 'PDL CRM gap-filler',
    prompt:
        'Create a scheduled workflow that finds CRM contacts missing key fields, runs People Data Labs to fill gaps, and writes coverage metrics to a hygiene table.',
    iconId: 'brand/people-data-labs-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'peopledatalabs-4',
    blockType: 'peopledatalabs',
    label: 'PDL lookalike expander',
    prompt:
        'Build a workflow that derives firmographic attributes from a seed account list and uses People Data Labs company-search to find similar companies, expanding the TAM and writing the new prospects into Salesforce.',
    iconId: 'brand/people-data-labs-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'peopledatalabs-5',
    blockType: 'peopledatalabs',
    label: 'PDL hiring-signal alerter',
    prompt:
        'Create a scheduled workflow that runs People Data Labs person-search for new hires in relevant roles at tracked accounts and posts a Slack alert when a match appears.',
    iconId: 'brand/people-data-labs-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'peopledatalabs-6',
    blockType: 'peopledatalabs',
    label: 'PDL + Email Bison outbound',
    prompt:
        'Build a workflow that runs People Data Labs on prospects, drafts a personalized first-touch email based on enrichment fields, and sends via Email Bison.',
    iconId: 'brand/people-data-labs-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'perplexity-0',
    blockType: 'perplexity',
    label: 'Perplexity research briefer',
    prompt:
        'Build an agent that takes a topic or company name, runs deep web research via Perplexity with citations, and saves a structured brief file with sources, key findings, and open questions.',
    iconId: 'brand/perplexity-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'perplexity-1',
    blockType: 'perplexity',
    label: 'Daily news brief via Perplexity',
    prompt:
        'Create a scheduled daily workflow that queries Perplexity for the latest news on topics I follow, summarizes each thread with citations, and posts the digest to Slack.',
    iconId: 'brand/perplexity-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'perplexity-2',
    blockType: 'perplexity',
    label: 'Perplexity multi-source research',
    prompt:
        'Create an agent that triangulates a topic across Perplexity, Exa, and Tavily, deduplicates findings, and produces a consensus brief with confidence scores per claim.',
    iconId: 'brand/perplexity-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'perplexity-3',
    blockType: 'perplexity',
    label: 'Perplexity sales account refresh',
    prompt:
        'Create a scheduled workflow that walks accounts in my CRM, runs Perplexity research on each for new funding, headcount changes, or product launches, and writes the digest back to the account record.',
    iconId: 'brand/perplexity-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'perplexity-4',
    blockType: 'perplexity',
    label: 'Perplexity + DSPy structured-output evaluator',
    prompt:
        'Build a workflow that runs DSPy programs against a Perplexity-backed retrieval layer, evaluates outputs with Hugging Face and Mistral parsers, and writes regression scores to a tracking table.',
    iconId: 'brand/perplexity-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'perplexity-5',
    blockType: 'perplexity',
    label: 'Perplexity + Hugging Face semantic dedup',
    prompt:
        'Build a workflow that runs Perplexity research, embeds findings with a Hugging Face encoder, deduplicates near-identical claims, and writes a clean research file.',
    iconId: 'brand/perplexity-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'perplexity-6',
    blockType: 'perplexity',
    label: 'Perplexity competitor-watch monitor',
    prompt:
        'Build a scheduled workflow that asks Perplexity for any new launches, pricing changes, or announcements from a list of competitors, summarizes what changed since last run, and posts a cited digest to a Slack channel for the product team.',
    iconId: 'brand/perplexity-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'persona-0',
    blockType: 'persona',
    label: 'Persona onboarding verification',
    prompt:
        'Build a workflow triggered when a new customer signs up that creates a Persona inquiry from our KYC template with their name and email pre-filled, generates a one-time verification link, and emails it to the customer.',
    iconId: 'brand/persona-icon',
    modules: <String>['workflows', 'agent'],
  ),
  SuggestionTemplate(
    id: 'persona-1',
    blockType: 'persona',
    label: 'Persona decision router',
    prompt:
        'Build a workflow that takes an inquiry ID, fetches the inquiry from Persona, and routes on its status: approved customers get a welcome email, needs-review inquiries post to a compliance Slack channel with a summary, and declined inquiries update our CRM.',
    iconId: 'brand/persona-icon',
    modules: <String>['workflows', 'agent'],
  ),
  SuggestionTemplate(
    id: 'persona-2',
    blockType: 'persona',
    label: 'Persona pending-review digest',
    prompt:
        'Build a scheduled workflow that runs every morning, lists Persona inquiries with needs_review status from the last 24 hours, summarizes each one, and posts a digest to the compliance team in Slack.',
    iconId: 'brand/persona-icon',
    modules: <String>['scheduled', 'workflows', 'agent'],
  ),
  SuggestionTemplate(
    id: 'persona-3',
    blockType: 'persona',
    label: 'Persona watchlist screening',
    prompt:
        'Build a workflow that takes a new user\'s name and birthdate, runs a Persona watchlist report against them, polls until the report is ready, and creates a case in our tracking table if the report has a match.',
    iconId: 'brand/persona-icon',
    modules: <String>['workflows', 'tables', 'agent'],
  ),
  SuggestionTemplate(
    id: 'persona-4',
    blockType: 'persona',
    label: 'Persona bulk account import',
    prompt:
        'Build a workflow that takes an uploaded CSV export of customers, imports them into Persona as accounts using the account importer, polls the importer status, and reports how many rows succeeded, errored, or were duplicates.',
    iconId: 'brand/persona-icon',
    modules: <String>['files', 'workflows', 'agent'],
  ),
  SuggestionTemplate(
    id: 'persona-5',
    blockType: 'persona',
    label: 'Persona audit PDF archive',
    prompt:
        'Build a workflow that takes an approved inquiry ID, downloads the inquiry summary PDF from Persona, and uploads it to a compliance archive folder in Google Drive named by customer reference ID.',
    iconId: 'brand/persona-icon',
    modules: <String>['workflows', 'files', 'agent'],
  ),
  SuggestionTemplate(
    id: 'persona-6',
    blockType: 'persona',
    label: 'Persona case triage agent',
    prompt:
        'Build an agent that lists open Persona cases, fetches the linked inquiry and verification details for each, drafts a recommended approve/decline decision with reasoning, and posts the triage summary to Slack for a human reviewer.',
    iconId: 'brand/persona-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'persona-7',
    blockType: 'persona',
    label: 'Persona re-verification campaign',
    prompt:
        'Build a scheduled workflow that lists Persona accounts, finds ones whose latest approved inquiry is older than a year, creates a new inquiry for each from our re-verification template, and emails customers a one-time verification link.',
    iconId: 'brand/persona-icon',
    modules: <String>['scheduled', 'workflows', 'agent'],
  ),
  SuggestionTemplate(
    id: 'pinecone-0',
    blockType: 'pinecone',
    label: 'Pinecone reindex pipeline',
    prompt:
        'Build a scheduled workflow that regenerates embeddings with OpenAI for new or changed source documents and upserts the vectors into a Pinecone index so retrieval stays current.',
    iconId: 'brand/pinecone-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'pinecone-1',
    blockType: 'pinecone',
    label: 'Pinecone semantic search agent',
    prompt:
        'Create an agent that takes a natural-language query, embeds it with OpenAI, retrieves top-k matches from Pinecone, and answers with cited passages plus a confidence score.',
    iconId: 'brand/pinecone-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'pinecone-2',
    blockType: 'pinecone',
    label: 'Pinecone retrieval-quality monitor',
    prompt:
        'Build a scheduled weekly workflow that runs a fixed set of benchmark queries against a Pinecone index, records top-k similarity scores per namespace to a table, and pings Slack when retrieval quality regresses.',
    iconId: 'brand/pinecone-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'pinecone-3',
    blockType: 'pinecone',
    label: 'Pinecone duplicate detector',
    prompt:
        'Create a workflow that reads a table of candidate records, embeds each with OpenAI, searches a Pinecone index for matches above a similarity threshold, and writes the near-duplicates to a cleanup queue.',
    iconId: 'brand/pinecone-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'pinecone-4',
    blockType: 'pinecone',
    label: 'Pinecone tenant isolation auditor',
    prompt:
        'Build a workflow that verifies Pinecone namespace isolation by sampling cross-namespace queries, ensuring no leakage, and writing a compliance audit report each week.',
    iconId: 'brand/pinecone-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'pinecone-5',
    blockType: 'pinecone',
    label: 'Pinecone FAQ deflection bot',
    prompt:
        'Create a workflow that embeds an incoming question with OpenAI, searches a Pinecone index of FAQ entries for the closest match, and returns the answer when similarity is high or escalates when it is not.',
    iconId: 'brand/pinecone-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'pinecone-6',
    blockType: 'pinecone',
    label: 'Pinecone support knowledge retriever',
    prompt:
        'Build a workflow that fetches each new Zendesk ticket, embeds the question with OpenAI, queries a Pinecone index of resolved tickets and docs, and drafts a suggested reply citing the most relevant matches for the agent to approve.',
    iconId: 'brand/pinecone-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'pipedrive-0',
    blockType: 'pipedrive',
    label: 'Pipedrive deal pipeline tracker',
    prompt:
        'Create a scheduled workflow that mirrors Pipedrive deals into a Sim table, calculates pipeline velocity per stage, and posts a daily Slack summary of deals at risk.',
    iconId: 'brand/pipedrive-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'pipedrive',
  ),
  SuggestionTemplate(
    id: 'pipedrive-1',
    blockType: 'pipedrive',
    label: 'Pipedrive lead enrichment pipeline',
    prompt:
        'Build a scheduled workflow that polls Pipedrive for new leads, enriches each via Apollo with role, seniority, and tech stack, and updates the lead with the enriched details.',
    iconId: 'brand/pipedrive-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'pipedrive',
  ),
  SuggestionTemplate(
    id: 'pipedrive-2',
    blockType: 'pipedrive',
    label: 'Pipedrive activity-from-email logger',
    prompt:
        'Create a workflow that watches Gmail for emails to or from Pipedrive contacts, logs each as an activity, and creates a follow-up task if next steps are mentioned.',
    iconId: 'brand/pipedrive-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'pipedrive',
  ),
  SuggestionTemplate(
    id: 'pipedrive-3',
    blockType: 'pipedrive',
    label: 'Pipedrive call-summary updater',
    prompt:
        'Build a workflow that runs after a Fireflies sales call, summarizes the transcript, and updates the matching Pipedrive deal with the call summary and next steps.',
    iconId: 'brand/pipedrive-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'pipedrive',
  ),
  SuggestionTemplate(
    id: 'pipedrive-4',
    blockType: 'pipedrive',
    label: 'Pipedrive win/loss analyzer',
    prompt:
        'Create a scheduled monthly workflow that pulls closed Pipedrive deals, analyzes patterns in wins vs losses, and writes an insights report file for the sales team.',
    iconId: 'brand/pipedrive-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
    providerId: 'pipedrive',
  ),
  SuggestionTemplate(
    id: 'pipedrive-5',
    blockType: 'pipedrive',
    label: 'Pipedrive renewal forecast',
    prompt:
        'Build a workflow that pulls Pipedrive customer renewals due in the next 90 days, generates a personalized renewal-prep brief, and emails the account owner.',
    iconId: 'brand/pipedrive-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'pipedrive',
  ),
  SuggestionTemplate(
    id: 'pipedrive-6',
    blockType: 'pipedrive',
    label: 'Pipedrive Slack channel-per-deal',
    prompt:
        'Create a workflow that for Pipedrive deals above a threshold creates a Slack channel, invites the account team, and pins the deal record link.',
    iconId: 'brand/pipedrive-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'pipedrive',
  ),
  SuggestionTemplate(
    id: 'pitchbook-0',
    blockType: 'pitchbook',
    label: 'PitchBook deal flow monitor',
    prompt:
        'Build a scheduled workflow that runs a PitchBook company search for early-stage VC deals in my target verticals closed in the last week, pulls each deal size and lead investor, writes them to a deal-flow table, and posts a digest to the investment team Slack channel.',
    iconId: 'brand/pitch-book-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'pitchbook-1',
    blockType: 'pitchbook',
    label: 'PitchBook company diligence brief',
    prompt:
        'Create an agent that takes a company name, resolves it to a PitchBook ID, pulls the bio, industries, investors, full deal history, and latest financials, then writes a diligence brief covering funding trajectory, cap table participants, and comparable companies.',
    iconId: 'brand/pitch-book-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'pitchbook-2',
    blockType: 'pitchbook',
    label: 'PitchBook investor targeting',
    prompt:
        'Build a workflow that takes my company profile and stage, searches PitchBook for investors whose stated preferences match on deal type, check size, industry, and geography, enriches each with their recent investments, and ranks the resulting target list in a table.',
    iconId: 'emcn/building',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'pitchbook-3',
    blockType: 'pitchbook',
    label: 'PitchBook fund performance tracker',
    prompt:
        'Create a scheduled workflow that pulls the latest IRR, TVPI, DPI, and benchmark quartile for each fund on my watchlist from PitchBook, appends the quarterly snapshot to a performance table, and flags any fund that has dropped a quartile.',
    iconId: 'brand/pitch-book-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'pitchbook-4',
    blockType: 'pitchbook',
    label: 'PitchBook competitor watch',
    prompt:
        'Build a scheduled workflow that fetches PitchBook similar companies for my main product, checks each one for new financing rounds and recent news, summarizes what changed with an agent, and emails the competitive brief to the product team every Monday.',
    iconId: 'brand/pitch-book-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'pitchbook-5',
    blockType: 'pitchbook',
    label: 'PitchBook LP commitment mapper',
    prompt:
        'Create a workflow that searches PitchBook limited partners matching a target profile, pulls their commitment history and preferences, and builds a table mapping which LPs back which fund types so the fundraising team knows who to approach.',
    iconId: 'emcn/building',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'pitchbook-6',
    blockType: 'pitchbook',
    label: 'PitchBook buying committee lookup',
    prompt:
        'Build a workflow that takes a target account, resolves it in PitchBook, pulls the current team and board members with their titles, filters to the decision-makers for my product, and syncs the mapped contacts into HubSpot.',
    iconId: 'brand/pitch-book-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'plane-0',
    blockType: 'plane',
    label: 'Plane backlog triage',
    prompt:
        'Build an agent that reads incoming Plane work items, resolves project states and labels, proposes triage decisions, and applies approved priority, ownership, and state changes.',
    iconId: 'brand/plane-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'plane-1',
    blockType: 'plane',
    label: 'Plane sprint planner',
    prompt:
        'Build an agent that selects ready Plane work items, creates a dated cycle, assigns those work items, and reports the resulting sprint scope.',
    iconId: 'brand/plane-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'plane-2',
    blockType: 'plane',
    label: 'Plane daily project digest',
    prompt:
        'Build a scheduled workflow that pages through Plane work items and sends a daily summary of overdue, blocked, and completed work to Slack.',
    iconId: 'brand/plane-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'plane-3',
    blockType: 'plane',
    label: 'Plane module progress report',
    prompt:
        'Build an agent that reads Plane modules and their work items, summarizes progress and overdue work, and reports the module lead and next steps.',
    iconId: 'brand/plane-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'plane-4',
    blockType: 'plane',
    label: 'Plane work item intake',
    prompt:
        'Build a workflow that receives requests, creates Plane work items with structured descriptions, and reports their IDs for triage.',
    iconId: 'brand/plane-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'plane-5',
    blockType: 'plane',
    label: 'Plane project documentation',
    prompt:
        'Build an agent that reads Plane project work items, summarizes decisions and progress, and updates a project page with the resulting documentation.',
    iconId: 'brand/plane-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'plane-6',
    blockType: 'plane',
    label: 'Plane self-hosted project sync',
    prompt:
        'Build a workflow that connects to my self-hosted Plane instance, pages through project work items, and syncs changed work items into a Sim table without losing the pagination cursor.',
    iconId: 'brand/plane-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'planetscale-0',
    blockType: 'planetscale',
    label: 'Database inventory',
    prompt:
        'Build a workflow. On a daily schedule, list PlanetScale databases and summarize their readiness and branch counts.',
    iconId: 'brand/planet-scale-icon',
    modules: <String>['workflows', 'scheduled'],
  ),
  SuggestionTemplate(
    id: 'planetscale-1',
    blockType: 'planetscale',
    label: 'Feature branch setup',
    prompt:
        'Build a workflow. When a GitHub pull request opens, create a PlanetScale development branch from its configured parent and report the new branch state.',
    iconId: 'brand/planet-scale-icon',
    modules: <String>['workflows'],
  ),
  SuggestionTemplate(
    id: 'planetscale-2',
    blockType: 'planetscale',
    label: 'Pre-deployment backup',
    prompt:
        'Build a workflow. Before an approved release, create a backup of the selected PlanetScale branch and return its ID and current state.',
    iconId: 'brand/planet-scale-icon',
    modules: <String>['workflows'],
  ),
  SuggestionTemplate(
    id: 'planetscale-3',
    blockType: 'planetscale',
    label: 'Backup health report',
    prompt:
        'Build a workflow. On a daily schedule, list backups for a PlanetScale branch and summarize successful and failed backups.',
    iconId: 'brand/planet-scale-icon',
    modules: <String>['workflows', 'scheduled'],
  ),
  SuggestionTemplate(
    id: 'planetscale-4',
    blockType: 'planetscale',
    label: 'Restore rehearsal',
    prompt:
        'Build a workflow. On a scheduled restore drill, select a successful backup, create a separate branch from it, and report the branch readiness. Run subsequent checks with the appropriate SQL integration.',
    iconId: 'brand/planet-scale-icon',
    modules: <String>['workflows', 'scheduled'],
  ),
  SuggestionTemplate(
    id: 'planetscale-5',
    blockType: 'planetscale',
    label: 'Schema release request',
    prompt:
        'Build a workflow. When a release is ready for schema review, create a Vitess deploy request from the development branch into the target branch and return its number and URL.',
    iconId: 'brand/planet-scale-icon',
    modules: <String>['workflows'],
  ),
  SuggestionTemplate(
    id: 'planetscale-6',
    blockType: 'planetscale',
    label: 'Deployment status report',
    prompt:
        'Build a workflow. On a schedule, list Vitess deploy requests and report their deployment states to Slack.',
    iconId: 'brand/planet-scale-icon',
    modules: <String>['workflows', 'scheduled'],
  ),
  SuggestionTemplate(
    id: 'planetscale-7',
    blockType: 'planetscale',
    label: 'Review and queue deployment',
    prompt:
        'Build a workflow. After explicit release approval, approve a Vitess deploy request, queue it, and report its current deployment state.',
    iconId: 'brand/planet-scale-icon',
    modules: <String>['workflows'],
  ),
  SuggestionTemplate(
    id: 'polymarket-0',
    blockType: 'polymarket',
    label: 'Polymarket position monitor',
    prompt:
        'Create a scheduled workflow that fetches Polymarket prices for tracked markets, computes price changes vs entry, writes the portfolio to a table, and pings Slack when any position swings beyond a threshold.',
    iconId: 'brand/polymarket-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'polymarket-1',
    blockType: 'polymarket',
    label: 'Polymarket research digest',
    prompt:
        'Build a scheduled weekly workflow that pulls top-volume Polymarket markets, summarizes the implied odds and recent moves, and writes a markdown research file for the trading group.',
    iconId: 'brand/polymarket-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'polymarket-2',
    blockType: 'polymarket',
    label: 'Polymarket price-move alerter',
    prompt:
        'Build a scheduled workflow that polls Polymarket prices for tracked markets, detects sharp moves since the last run, and writes the price reactions to a research table.',
    iconId: 'brand/polymarket-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'polymarket-3',
    blockType: 'polymarket',
    label: 'Polymarket + Similarweb event volume tracker',
    prompt:
        'Create a workflow that overlays Polymarket market activity with Similarweb traffic for the involved entities, identifies volume-driving news, and writes the analysis.',
    iconId: 'brand/polymarket-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'polymarket-4',
    blockType: 'polymarket',
    label: 'Polymarket large-order tracker',
    prompt:
        'Build a scheduled workflow that pulls Polymarket order book activity, identifies unusually large orders on tracked markets, and pings Slack on whale activity.',
    iconId: 'brand/polymarket-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'polymarket-5',
    blockType: 'polymarket',
    label: 'Polymarket position digest',
    prompt:
        'Create a scheduled daily workflow that summarizes Polymarket holdings, PnL per market, and notable movements, and emails the report to the trading team.',
    iconId: 'brand/polymarket-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'polymarket-6',
    blockType: 'polymarket',
    label: 'Polymarket arbitrage scanner',
    prompt:
        'Build a scheduled workflow that fetches prices for related Polymarket markets, detects when complementary outcomes sum away from fair value, writes the mispriced pairs to a table, and pings Slack with the implied edge for each opportunity.',
    iconId: 'brand/polymarket-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'postgresql-0',
    blockType: 'postgresql',
    label: 'Ask Postgres in plain English',
    prompt:
        'Build a workflow that takes a natural-language question, has an agent turn it into a PostgreSQL SELECT query, runs it against the database, and returns the resulting rows as a readable answer.',
    iconId: 'brand/postgres-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'postgresql-1',
    blockType: 'postgresql',
    label: 'Postgres metrics digest to Slack',
    prompt:
        'Create a scheduled workflow that queries key business metrics from PostgreSQL each morning, has an agent summarize the numbers and notable changes, and posts the digest to a Slack channel.',
    iconId: 'brand/postgres-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'postgresql-2',
    blockType: 'postgresql',
    label: 'Document your Postgres schema',
    prompt:
        'Build a workflow that introspects a PostgreSQL schema to list its tables, columns, keys, and indexes, then has an agent write plain-English documentation describing what each table holds.',
    iconId: 'brand/postgres-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'postgresql-3',
    blockType: 'postgresql',
    label: 'Upsert records into Postgres',
    prompt:
        'Create a workflow that takes incoming records, checks PostgreSQL for an existing row by key, then inserts a new row or updates the existing one so the table stays in sync without duplicates.',
    iconId: 'brand/postgres-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'postgresql-4',
    blockType: 'postgresql',
    label: 'Nightly Postgres data cleanup',
    prompt:
        'Build a scheduled workflow that deletes rows in PostgreSQL older than a retention cutoff and reports how many rows were removed, so tables stay lean on an interval.',
    iconId: 'brand/postgres-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'postgresql-5',
    blockType: 'postgresql',
    label: 'Postgres results to Sim table',
    prompt:
        'Create a scheduled workflow that runs a PostgreSQL query for the latest records and writes each row into a Sim table, so the data is available for downstream blocks without a live database call.',
    iconId: 'brand/postgres-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'postgresql-6',
    blockType: 'postgresql',
    label: 'Postgres threshold breach alert',
    prompt:
        'Build a scheduled workflow that queries a PostgreSQL count or aggregate, compares it to a threshold, and posts a Slack alert only when the value crosses the limit so the team hears about problems early.',
    iconId: 'brand/postgres-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'postgresql-7',
    blockType: 'postgresql',
    label: 'Log form submissions to Postgres',
    prompt:
        'Create a workflow that takes an incoming payload, validates the fields, and inserts a new row into a PostgreSQL table so every submission is durably recorded.',
    iconId: 'brand/postgres-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'posthog-0',
    blockType: 'posthog',
    label: 'PostHog insight digest',
    prompt:
        'Create a scheduled daily workflow that pulls key PostHog insights — DAU, top events, funnels — and posts a digest to Slack with week-over-week deltas and emoji indicators.',
    iconId: 'brand/posthog-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'posthog-1',
    blockType: 'posthog',
    label: 'PostHog feature flag flip notifier',
    prompt:
        'Build a scheduled workflow that polls PostHog feature flags, detects status changes since the last run, and posts a Slack notification with the old and new state for each changed flag.',
    iconId: 'brand/posthog-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'posthog-2',
    blockType: 'posthog',
    label: 'PostHog session replay triage',
    prompt:
        'Create a scheduled workflow that lists PostHog session recordings with rage clicks or dead clicks, scores each for severity, and creates a Linear ticket for the worst sessions.',
    iconId: 'brand/posthog-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'posthog-3',
    blockType: 'posthog',
    label: 'PostHog event taxonomy enforcer',
    prompt:
        'Build a workflow that scans PostHog events daily, flags any new event names that violate the naming convention, and opens a Linear ticket for the engineer to clean up tracking debt.',
    iconId: 'brand/posthog-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'posthog-4',
    blockType: 'posthog',
    label: 'PostHog cohort enrichment',
    prompt:
        'Create a workflow that pulls a PostHog cohort, enriches each user with HubSpot lifecycle stage and Stripe LTV, and writes the enriched cohort to a tables-based targeting view.',
    iconId: 'brand/posthog-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'posthog-5',
    blockType: 'posthog',
    label: 'PostHog + Profound user-journey enricher',
    prompt:
        'Build a scheduled weekly workflow that joins PostHog user journeys with Profound AI brand signal to identify how AI-driven discovery converts, and writes a report.',
    iconId: 'brand/posthog-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'posthog-6',
    blockType: 'posthog',
    label: 'PostHog survey response analyzer',
    prompt:
        'Create a scheduled workflow that lists active PostHog surveys, pulls their responses with a query, runs sentiment and theme analysis across the open-text answers, and posts a summary of top themes and NPS movement to Slack.',
    iconId: 'brand/posthog-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'powerbi-0',
    blockType: 'powerbi',
    label: 'Power BI KPI briefing',
    prompt:
        'Build a scheduled workflow that runs an approved DAX query for daily KPIs in a Power BI semantic model, summarizes successful results, and posts the briefing to Microsoft Teams. Connect the query block\'s error port to a separate failure notification.',
    iconId: 'brand/power-bi-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'microsoft-powerbi',
  ),
  SuggestionTemplate(
    id: 'powerbi-1',
    blockType: 'powerbi',
    label: 'Power BI sales target alert',
    prompt:
        'Create a scheduled workflow that queries approved sales and target measures from a Power BI semantic model, compares complete results with a configured threshold, and alerts the sales team in Slack when the target is missed.',
    iconId: 'brand/power-bi-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'microsoft-powerbi',
  ),
  SuggestionTemplate(
    id: 'powerbi-2',
    blockType: 'powerbi',
    label: 'Power BI report catalog',
    prompt:
        'Build a scheduled workflow that lists accessible Power BI workspaces and their reports, collects report links and semantic model IDs when available, and updates a Sim table as a searchable report catalog.',
    iconId: 'brand/power-bi-icon',
    modules: <String>['scheduled', 'tables', 'workflows'],
    providerId: 'microsoft-powerbi',
  ),
  SuggestionTemplate(
    id: 'powerbi-3',
    blockType: 'powerbi',
    label: 'Power BI model inventory',
    prompt:
        'Create a scheduled workflow that inventories semantic models in selected accessible workspaces, records names and available owner and refresh metadata in a Sim table, and summarizes missing metadata without assuming read-only responses are complete.',
    iconId: 'brand/power-bi-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'microsoft-powerbi',
  ),
  SuggestionTemplate(
    id: 'powerbi-4',
    blockType: 'powerbi',
    label: 'Power BI pipeline refresh',
    prompt:
        'Build a workflow started by an upstream pipeline completion request that asks Power BI to refresh a selected semantic model and records the acceptance and request ID in a Sim table. Notify Microsoft Teams that the refresh was requested, then use a separate scheduled history check to observe completion.',
    iconId: 'brand/power-bi-icon',
    modules: <String>['tables', 'workflows', 'scheduled'],
    providerId: 'microsoft-powerbi',
  ),
  SuggestionTemplate(
    id: 'powerbi-5',
    blockType: 'powerbi',
    label: 'Power BI refresh failure monitor',
    prompt:
        'Create a scheduled workflow that retrieves refresh history for critical Power BI semantic models, identifies failed requests and their error details, and notifies an operations Slack channel once per request ID using a Sim table to track previously reported failures.',
    iconId: 'brand/power-bi-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'microsoft-powerbi',
  ),
  SuggestionTemplate(
    id: 'powerbi-6',
    blockType: 'powerbi',
    label: 'Power BI freshness watch',
    prompt:
        'Build a scheduled workflow that reads semantic model refresh history, compares the most recent completed refresh with an agreed freshness deadline, and sends Microsoft Teams a stale-data warning when the deadline is missed. Report Unknown statuses separately without claiming a refresh has completed.',
    iconId: 'brand/power-bi-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'microsoft-powerbi',
  ),
  SuggestionTemplate(
    id: 'profound-0',
    blockType: 'profound',
    label: 'Profound AI-visibility tracker',
    prompt:
        'Create a scheduled weekly workflow that pulls Profound brand-visibility scores across AI search engines, tracks how my brand surfaces in answers for tracked prompts, and reports week-over-week shifts to Slack.',
    iconId: 'brand/profound-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'profound-1',
    blockType: 'profound',
    label: 'Profound competitor share-of-voice',
    prompt:
        'Build a workflow that pulls Profound competitor share-of-voice across AI engines, writes the leaderboard to a tracking table, and flags when a competitor jumps more than two positions.',
    iconId: 'brand/profound-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'profound-2',
    blockType: 'profound',
    label: 'Profound prompt-coverage audit',
    prompt:
        'Build a scheduled weekly workflow that reads Profound\'s tracked-prompt coverage and prompt answers to monitor how my brand surfaces in AI answers across engines, and writes the coverage scorecard to a tables-based report.',
    iconId: 'brand/profound-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'profound-3',
    blockType: 'profound',
    label: 'Profound citation-source tracker',
    prompt:
        'Build a scheduled workflow that pulls the sources Profound reports AI engines cite when answering brand prompts, logs the citing domains and pages to a table, and flags new sources the content team should target.',
    iconId: 'brand/profound-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'profound-4',
    blockType: 'profound',
    label: 'Profound visibility-drop alerter',
    prompt:
        'Create a workflow that checks Profound brand-visibility scores daily, compares each tracked prompt against its baseline, and immediately pages the marketing on-call in Slack when visibility drops sharply on a high-priority prompt.',
    iconId: 'brand/profound-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'profound-5',
    blockType: 'profound',
    label: 'Profound content-gap planner',
    prompt:
        'Build a workflow that pulls the prompts where Profound shows my brand is absent from AI answers, has an agent draft a prioritized content brief for each gap, and creates the briefs as Notion pages for the content team.',
    iconId: 'brand/profound-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'profound-6',
    blockType: 'profound',
    label: 'Profound executive AI-search digest',
    prompt:
        'Create a scheduled monthly workflow that aggregates Profound visibility, share-of-voice, and citation trends into a Markdown report file with commentary, and emails the AI-search performance digest to leadership.',
    iconId: 'brand/profound-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'prospeo-0',
    blockType: 'prospeo',
    label: 'Prospeo email finder',
    prompt:
        'Build a workflow that takes a prospect name and company from a table, runs Prospeo to find and verify their work email, and writes the deliverable contact back to the row.',
    iconId: 'brand/prospeo-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'prospeo-1',
    blockType: 'prospeo',
    label: 'Prospeo person enricher',
    prompt:
        'Create a workflow that watches CRM contacts, runs Prospeo enrichment to fill in title, company, and verified contact details, and writes the enriched fields back.',
    iconId: 'brand/prospeo-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'prospeo-2',
    blockType: 'prospeo',
    label: 'Prospeo ICP search',
    prompt:
        'Build a workflow that runs a Prospeo people search against my ICP filters, reveals verified emails and mobile numbers, and writes the prospect list into a sender table.',
    iconId: 'brand/prospeo-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'prospeo-3',
    blockType: 'prospeo',
    label: 'Prospeo + Email Bison outbound',
    prompt:
        'Create a workflow that uses Prospeo to find and verify prospect emails, drafts a personalized first-touch message, and pushes valid prospects into an Email Bison campaign.',
    iconId: 'brand/prospeo-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'prospeo-4',
    blockType: 'prospeo',
    label: 'Prospeo CRM gap-filler',
    prompt:
        'Build a scheduled workflow that finds Salesforce contacts missing email addresses, runs Prospeo to find and verify them, and updates each contact record.',
    iconId: 'brand/prospeo-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'prospeo-5',
    blockType: 'prospeo',
    label: 'Prospeo bulk list enrichment',
    prompt:
        'Build a workflow that reads a large prospect list from a table, runs Prospeo bulk person enrichment in batches to reveal verified emails and titles, and writes the enriched results back row by row with a status column for any that could not be matched.',
    iconId: 'brand/prospeo-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'prospeo-6',
    blockType: 'prospeo',
    label: 'Prospeo company enrichment',
    prompt:
        'Create a workflow that takes a list of target company domains, runs Prospeo company enrichment to pull firmographics like size, industry, and location, and writes the structured company profiles into an account table for territory planning.',
    iconId: 'brand/prospeo-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'pulse-0',
    blockType: 'pulse',
    label: 'Pulse invoice extractor',
    prompt:
        'Create a workflow that runs each uploaded invoice PDF through Pulse OCR, extracts vendor, line items, and totals into structured fields, and writes the parsed records to an accounts-payable table.',
    iconId: 'brand/pulse-icon',
    modules: <String>['files', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'pulse-1',
    blockType: 'pulse',
    label: 'Pulse contract clause extractor',
    prompt:
        'Build a workflow that extracts the full text of uploaded contract PDFs with Pulse OCR, has an agent pull out key clauses, parties, and renewal dates, and writes a structured summary to a table.',
    iconId: 'brand/pulse-icon',
    modules: <String>['files', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'pulse-2',
    blockType: 'pulse',
    label: 'Pulse scanned-document indexer',
    prompt:
        'Create a workflow that runs each scanned image or PDF through Pulse OCR, chunks the extracted markdown, and indexes the cleaned content into a knowledge base so agents can search across every document.',
    iconId: 'brand/pulse-icon',
    modules: <String>['files', 'knowledge-base', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'pulse-3',
    blockType: 'pulse',
    label: 'Pulse form data extractor',
    prompt:
        'Build a workflow that extracts text from uploaded form PDFs and images with Pulse OCR, maps the values into structured fields with an agent, and writes each submission to a table.',
    iconId: 'brand/pulse-icon',
    modules: <String>['files', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'pulse-4',
    blockType: 'pulse',
    label: 'Pulse table-to-spreadsheet extractor',
    prompt:
        'Create a workflow that runs uploaded reports through Pulse OCR, pulls the embedded tables into structured rows, and writes the consolidated data to a tracking table.',
    iconId: 'brand/pulse-icon',
    modules: <String>['files', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'pulse-5',
    blockType: 'pulse',
    label: 'Pulse document summarizer',
    prompt:
        'Build a workflow that extracts the text of an uploaded PDF or Office file with Pulse OCR, has an agent write a concise summary, and posts it to Slack.',
    iconId: 'brand/pulse-icon',
    modules: <String>['files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'pulse-6',
    blockType: 'pulse',
    label: 'Pulse document OCR pipeline',
    prompt:
        'Build a workflow that runs each uploaded PDF, image, or Office file through Pulse OCR, extracts the text into structured rows in a table, and indexes the cleaned content into a knowledge base so agents can search across every scanned document.',
    iconId: 'brand/pulse-icon',
    modules: <String>[
      'files',
      'tables',
      'knowledge-base',
      'agent',
      'workflows',
    ],
  ),
  SuggestionTemplate(
    id: 'qdrant-0',
    blockType: 'qdrant',
    label: 'Qdrant document ingestion',
    prompt:
        'Build a workflow that watches a Google Drive folder for new docs, chunks each, generates embeddings, and upserts the vectors into a Qdrant collection with rich metadata.',
    iconId: 'brand/qdrant-icon',
    modules: <String>['files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'qdrant-1',
    blockType: 'qdrant',
    label: 'Qdrant retrieval agent',
    prompt:
        'Create an agent that performs hybrid search against a Qdrant collection — semantic + filter conditions — and answers user questions with the matched documents cited.',
    iconId: 'brand/qdrant-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'qdrant-2',
    blockType: 'qdrant',
    label: 'Qdrant payload schema migrator',
    prompt:
        'Build a workflow that scans a Qdrant collection, migrates payload schema to a new version with backfilled fields, and writes the migration plan and outcome to an audit table.',
    iconId: 'brand/qdrant-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'qdrant-3',
    blockType: 'qdrant',
    label: 'Qdrant + knowledge base sync',
    prompt:
        'Create a workflow that mirrors a Sim knowledge base into a Qdrant collection so downstream applications outside Sim can perform retrieval against the same vectors.',
    iconId: 'brand/qdrant-icon',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'qdrant-4',
    blockType: 'qdrant',
    label: 'Qdrant snapshot manager',
    prompt:
        'Build a scheduled workflow that takes a Qdrant collection snapshot each night, uploads it to S3 with retention rotation, and writes the snapshot manifest to a tracking table.',
    iconId: 'brand/qdrant-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'qdrant-5',
    blockType: 'qdrant',
    label: 'Qdrant abandoned-document detector',
    prompt:
        'Create a workflow that scans a Qdrant collection for vectors whose source document no longer exists, deletes the orphans, and writes a hygiene report each week.',
    iconId: 'brand/qdrant-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'qdrant-6',
    blockType: 'qdrant',
    label: 'Qdrant support-answer retriever',
    prompt:
        'Build a workflow that embeds each new Zendesk ticket with OpenAI, runs a filtered Qdrant search scoped to the customer’s product, and drafts a cited reply from the closest matching resolved tickets for the agent to approve.',
    iconId: 'brand/qdrant-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'quartr-0',
    blockType: 'quartr',
    label: 'Quartr earnings call digest',
    prompt:
        'Create a scheduled workflow that lists yesterday’s Quartr events for my watchlist tickers, fetches the AI-generated summary for each event, and posts a digest with source links to Slack.',
    iconId: 'brand/quartr-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'quartr-1',
    blockType: 'quartr',
    label: 'Quartr transcript knowledge base',
    prompt:
        'Build a scheduled workflow that lists new Quartr earnings call transcripts for companies I follow, downloads each transcript file, and indexes the content into a knowledge base so agents can answer questions about past calls.',
    iconId: 'brand/quartr-icon',
    modules: <String>['scheduled', 'knowledge-base', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'quartr-2',
    blockType: 'quartr',
    label: 'Quartr filing watcher',
    prompt:
        'Create a scheduled workflow that checks Quartr daily for new annual and interim reports from my portfolio companies, downloads each report PDF to Files, and emails me a summary of what was filed.',
    iconId: 'brand/quartr-icon',
    modules: <String>['scheduled', 'files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'quartr-3',
    blockType: 'quartr',
    label: 'Quartr slide deck analyst',
    prompt:
        'Build a workflow that fetches the latest Quartr slide deck for a given ticker, has an agent extract guidance, KPIs, and notable changes from the deck, and writes the analysis to a table.',
    iconId: 'brand/quartr-icon',
    modules: <String>['agent', 'tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'quartr-4',
    blockType: 'quartr',
    label: 'Quartr live earnings monitor',
    prompt:
        'Create a scheduled workflow that polls Quartr live events for my watchlist, and when a company goes live, posts the live audio and transcript stream links to a Slack channel.',
    iconId: 'brand/quartr-icon',
    modules: <String>['scheduled', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'quartr-5',
    blockType: 'quartr',
    label: 'Quartr competitor earnings tracker',
    prompt:
        'Build a workflow that reads competitor tickers from a table, lists each company’s recent Quartr events and event summaries, and logs revenue and guidance highlights back to the table for quarter-over-quarter comparison.',
    iconId: 'brand/quartr-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'quartr-6',
    blockType: 'quartr',
    label: 'Quartr earnings Q&A agent',
    prompt:
        'Create an agent that answers questions about a company’s earnings by looking up the company on Quartr, finding its latest earnings call event, and grounding answers in the event summary and transcript.',
    iconId: 'brand/quartr-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'quickbooks-0',
    blockType: 'quickbooks',
    label: 'QuickBooks customer onboarding',
    prompt:
        'Build a workflow that receives an approved customer profile, creates the QuickBooks customer, and stores its ID and record version in a Sim table.',
    iconId: 'brand/quick-books-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'quickbooks',
  ),
  SuggestionTemplate(
    id: 'quickbooks-1',
    blockType: 'quickbooks',
    label: 'QuickBooks vendor onboarding',
    prompt:
        'Create a workflow that receives approved vendor identity, contact, address, and 1099 details, creates the QuickBooks vendor, and stores the returned ID and record version.',
    iconId: 'brand/quick-books-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'quickbooks',
  ),
  SuggestionTemplate(
    id: 'quickbooks-2',
    blockType: 'quickbooks',
    label: 'QuickBooks catalogue maintenance',
    prompt:
        'Build a workflow that reads filtered QuickBooks master data, creates approved non-payroll employees or Service and Non-inventory items, and safely updates exposed fields while retaining returned IDs and record versions.',
    iconId: 'brand/quick-books-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'quickbooks',
  ),
  SuggestionTemplate(
    id: 'quickbooks-3',
    blockType: 'quickbooks',
    label: 'QuickBooks monthly and year-end reporting',
    prompt:
        'Build a scheduled workflow that runs monthly and year-end Balance Sheet, Profit and Loss, Trial Balance, and Cash Flow reports, preserves their native rows and summaries, and stores review results in a Sim table.',
    iconId: 'brand/quick-books-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'quickbooks',
  ),
  SuggestionTemplate(
    id: 'quickbooks-4',
    blockType: 'quickbooks',
    label: 'QuickBooks estimate preparation',
    prompt:
        'Build a workflow that receives an approved customer quote and line items, creates a QuickBooks estimate, and stores its ID and record version for controlled revisions.',
    iconId: 'brand/quick-books-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'quickbooks',
  ),
  SuggestionTemplate(
    id: 'quickbooks-5',
    blockType: 'quickbooks',
    label: 'QuickBooks invoice creation and delivery',
    prompt:
        'Create a workflow that validates approved customer and item IDs, creates a QuickBooks invoice, stores its ID and record version, then—after explicit approval—emails it or downloads its PDF for controlled delivery and archiving.',
    iconId: 'brand/quick-books-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'quickbooks',
  ),
  SuggestionTemplate(
    id: 'quickbooks-6',
    blockType: 'quickbooks',
    label: 'QuickBooks partial-payment application',
    prompt:
        'Build a workflow that records a customer payment, applies bounded amounts to approved QuickBooks invoice IDs, and reports any unapplied remainder.',
    iconId: 'brand/quick-books-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'quickbooks',
  ),
  SuggestionTemplate(
    id: 'quickbooks-7',
    blockType: 'quickbooks',
    label: 'QuickBooks journal adjustments and deposits',
    prompt:
        'Build a controlled workflow that posts an explicitly approved, balanced QuickBooks journal entry or records a bounded deposit, then runs cash- and accrual-basis reports to support the accounting review.',
    iconId: 'brand/quick-books-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'quickbooks',
  ),
  SuggestionTemplate(
    id: 'quickbooks-8',
    blockType: 'quickbooks',
    label: 'QuickBooks receivables and payables aging',
    prompt:
        'Create a scheduled workflow that runs A/R and A/P aging summaries and details with approved aging controls, optionally filters by customer or vendor, and flags balances requiring accountant review without changing records.',
    iconId: 'brand/quick-books-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'quickbooks',
  ),
  SuggestionTemplate(
    id: 'quickbooks-9',
    blockType: 'quickbooks',
    label: 'QuickBooks bill entry and payment',
    prompt:
        'Build a controlled workflow that reads an approved Purchase Order by ID, captures its Line IDs, creates a QuickBooks Bill with explicit PO-line mappings, checks linkingSucceeded and missingLinks, attaches one approved receipt or audit note, and records a separately approved payment only after reviewing the created Bill.',
    iconId: 'brand/quick-books-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'quickbooks',
  ),
  SuggestionTemplate(
    id: 'quickbooks-10',
    blockType: 'quickbooks',
    label: 'QuickBooks customer, vendor, and expense analysis',
    prompt:
        'Create a workflow that runs customer and vendor balance reports, expenses by vendor, or the Transaction List with bounded date, entity, paid-status, cleared-status, document-number, grouping, and source-account filters for accountant review.',
    iconId: 'brand/quick-books-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'quickbooks',
  ),
  SuggestionTemplate(
    id: 'quiver-0',
    blockType: 'quiver',
    label: 'Quiver SVG icon generator',
    prompt:
        'Build a workflow that takes a product name and brand color as inputs, generates a matching SVG icon with Quiver, and saves it to the files store.',
    iconId: 'brand/quiver-icon',
    modules: <String>['files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'quiver-1',
    blockType: 'quiver',
    label: 'Quiver diagram creator',
    prompt:
        'Create a workflow that reads structured data from a table and uses Quiver to generate a clean SVG diagram visualizing the data, then attaches it to a Slack message.',
    iconId: 'brand/quiver-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'quiver-2',
    blockType: 'quiver',
    label: 'Quiver image vectorizer',
    prompt:
        'Build a workflow that accepts a raster image upload, vectorizes it to SVG with Quiver, and returns the clean SVG for use in presentations or exports.',
    iconId: 'brand/quiver-icon',
    modules: <String>['files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rabbitmq-0',
    blockType: 'rabbitmq',
    label: 'RabbitMQ dead-letter triage',
    prompt:
        'Build a scheduled workflow that reads messages off the RabbitMQ dead-letter queue every 15 minutes, groups them by failure reason, writes the groups to a table, and posts a summary to Slack.',
    iconId: 'brand/rabbitmq-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rabbitmq-1',
    blockType: 'rabbitmq',
    label: 'RabbitMQ queue depth alerting',
    prompt:
        'Create a scheduled workflow that lists RabbitMQ queues every five minutes, flags any queue whose depth exceeds its threshold or that has zero consumers, and opens a PagerDuty incident.',
    iconId: 'brand/rabbitmq-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rabbitmq-2',
    blockType: 'rabbitmq',
    label: 'Publish enriched events to RabbitMQ',
    prompt:
        'Build a workflow that receives an inbound webhook, enriches the payload with an agent, and publishes the result to a RabbitMQ topic exchange with a routing key derived from the event type.',
    iconId: 'brand/rabbitmq-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rabbitmq-3',
    blockType: 'rabbitmq',
    label: 'RabbitMQ to Slack incident relay',
    prompt:
        'Create a scheduled workflow that drains a RabbitMQ alerts queue, summarizes each message with an agent, and posts the summary to the on-call Slack channel with a severity label.',
    iconId: 'brand/rabbitmq-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rabbitmq-4',
    blockType: 'rabbitmq',
    label: 'RabbitMQ order pipeline bootstrap',
    prompt:
        'Build a workflow that declares the RabbitMQ queues and exchange bindings an order pipeline needs, verifies each binding, and records the resulting topology in a table.',
    iconId: 'brand/rabbitmq-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rabbitmq-5',
    blockType: 'rabbitmq',
    label: 'RabbitMQ broker health digest',
    prompt:
        'Create a scheduled daily workflow that reads the RabbitMQ broker overview and queue list, compares depth and consumer counts against yesterday, and emails the platform team a health digest.',
    iconId: 'brand/rabbitmq-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rabbitmq-6',
    blockType: 'rabbitmq',
    label: 'RabbitMQ replay after an outage',
    prompt:
        'Build a workflow that reads messages from a RabbitMQ parking queue, has an agent decide which are safe to replay, republishes those to the live exchange, and logs every skipped message with its reason.',
    iconId: 'brand/rabbitmq-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rabbitmq-7',
    blockType: 'rabbitmq',
    label: 'RabbitMQ capacity review',
    prompt:
        'Create a scheduled weekly workflow that lists every RabbitMQ queue and exchange, identifies unused queues and queues with no bindings, and posts a cleanup proposal to a Linear issue.',
    iconId: 'brand/rabbitmq-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rabbitmq-8',
    blockType: 'rabbitmq',
    label: 'RabbitMQ cluster alarm watch',
    prompt:
        'Create a scheduled workflow that runs the RabbitMQ health checks every five minutes, lists cluster nodes for memory and disk alarms and network partitions, and pages on-call when an alarm fires.',
    iconId: 'brand/rabbitmq-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rabbitmq-9',
    blockType: 'rabbitmq',
    label: 'RabbitMQ stalled consumer detector',
    prompt:
        'Build a scheduled workflow that cross-references RabbitMQ queue depth with consumers and channels, flags queues whose consumers are inactive or whose unacknowledged counts are stuck at the prefetch limit, and posts the findings to Slack.',
    iconId: 'brand/rabbitmq-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rabbitmq-10',
    blockType: 'rabbitmq',
    label: 'RabbitMQ dead-letter policy rollout',
    prompt:
        'Create a workflow that audits RabbitMQ policies across virtual hosts, finds queue families with no dead-letter exchange configured, and applies a standard dead-lettering policy after posting the plan for approval.',
    iconId: 'brand/rabbitmq-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'railway-0',
    blockType: 'railway',
    label: 'Railway deployment monitor',
    prompt:
        'Build a scheduled workflow that lists the latest Railway deployments across my services every few minutes, detects failed or crashed deployments, summarizes the failure with an agent, and posts an actionable Slack alert with a link to the service.',
    iconId: 'brand/railway-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'railway-1',
    blockType: 'railway',
    label: 'Railway deploy on merge',
    prompt:
        'Create a workflow that watches GitHub for merges to the main branch, triggers a Railway service deployment for the matching environment, and posts the deployment status back as a Slack notification.',
    iconId: 'brand/railway-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'railway-2',
    blockType: 'railway',
    label: 'Railway environment variable auditor',
    prompt:
        'Build a scheduled weekly workflow that lists environment variables across every Railway project, compares them to a reference list in a table, flags drift and missing keys, and emails a remediation report to the platform team.',
    iconId: 'brand/railway-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'railway-3',
    blockType: 'railway',
    label: 'Railway project inventory',
    prompt:
        'Create a scheduled workflow that lists every Railway project, its services, and environments weekly, logs them into a tracking table, and Slacks a diff of any added or removed resources so infrastructure changes never go unnoticed.',
    iconId: 'brand/railway-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'railway-4',
    blockType: 'railway',
    label: 'Railway config sync',
    prompt:
        'Build a workflow that reads service configuration from a table and upserts the matching Railway environment variables for each service, then posts a Slack summary of every variable that was created or changed.',
    iconId: 'brand/railway-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'railway-5',
    blockType: 'railway',
    label: 'Railway preview environment provisioner',
    prompt:
        'Create a workflow that watches GitHub for new pull requests, creates a fresh Railway environment for the branch, upserts the required environment variables, deploys the service, and comments the live preview URL back on the PR.',
    iconId: 'brand/railway-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'railway-6',
    blockType: 'railway',
    label: 'Railway project onboarding kit',
    prompt:
        'Build a workflow that takes a new service name, creates a Railway project, sets up staging and production environments, seeds baseline environment variables from a table, and posts the project members and access summary to Slack for the team.',
    iconId: 'brand/railway-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ramp-0',
    blockType: 'ramp',
    label: 'Weekly Spend Review',
    prompt:
        'Every week, read Ramp transactions for the previous week, group spending by merchant and currency, and produce a summary with unusually large expenses and transaction IDs.',
    iconId: 'brand/ramp-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'ramp',
  ),
  SuggestionTemplate(
    id: 'ramp-1',
    blockType: 'ramp',
    label: 'Reimbursement Review Queue',
    prompt:
        'Each morning, list pending Ramp reimbursements, read the details needed for review, and produce a queue with employee names, amounts, merchants, and submission dates.',
    iconId: 'brand/ramp-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'ramp',
  ),
  SuggestionTemplate(
    id: 'ramp-2',
    blockType: 'ramp',
    label: 'Upcoming Bill Report',
    prompt:
        'Each day, list open Ramp bills due in the next seven days and produce a report grouped by vendor, currency, approval status, and due date.',
    iconId: 'brand/ramp-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'ramp',
  ),
  SuggestionTemplate(
    id: 'ramp-3',
    blockType: 'ramp',
    label: 'Vendor Spend Summary',
    prompt:
        'At month end, list Ramp vendors and compare their last 30 days and year-to-date spend. Produce a ranked vendor report with vendor IDs and currencies.',
    iconId: 'brand/ramp-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'ramp',
  ),
  SuggestionTemplate(
    id: 'ramp-4',
    blockType: 'ramp',
    label: 'Employee Card Inventory',
    prompt:
        'When given an employee email, find the Ramp user, list their physical and virtual cards, and return an inventory with card status and suspension flags.',
    iconId: 'brand/ramp-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'ramp',
  ),
  SuggestionTemplate(
    id: 'ramp-5',
    blockType: 'ramp',
    label: 'Transaction Memo Assistant',
    prompt:
        'When a finance reviewer supplies a transaction ID and approved business purpose, read the transaction and its memo, add the supplied memo in Ramp, and return the saved memo.',
    iconId: 'brand/ramp-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'ramp',
  ),
  SuggestionTemplate(
    id: 'ramp-6',
    blockType: 'ramp',
    label: 'Available Credit Snapshot',
    prompt:
        'Each business morning, read the Ramp business and balance, and produce a snapshot of the card limit, available card spending, statement balance, and next billing date.',
    iconId: 'brand/ramp-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'ramp',
  ),
  SuggestionTemplate(
    id: 'ramp-7',
    blockType: 'ramp',
    label: 'Accounting Close Review',
    prompt:
        'Before month end, list Ramp transactions with accounting sync status SYNC_READY and reimbursements ready to sync, and produce a checklist with IDs and amounts for the accounting team.',
    iconId: 'brand/ramp-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'ramp',
  ),
  SuggestionTemplate(
    id: 'rb2b-0',
    blockType: 'rb2b',
    label: 'RB2B visitor de-anonymizer',
    prompt:
        'Build a workflow that takes the IP addresses of anonymous website visitors, uses RB2B to resolve each IP to a hashed email and company domain, and writes the identified visitors into a table for the sales team.',
    iconId: 'brand/rb2-b-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rb2b-1',
    blockType: 'rb2b',
    label: 'RB2B IP to LinkedIn profile',
    prompt:
        'Create a workflow that resolves a visitor IP to a hashed email with RB2B, then enriches that hashed email into a LinkedIn profile and business profile so reps know exactly who visited.',
    iconId: 'brand/rb2-b-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rb2b-2',
    blockType: 'rb2b',
    label: 'RB2B hashed-email enrichment',
    prompt:
        'Build a workflow that reads hashed emails from a table, uses RB2B to enrich each into a full business profile with name, title, seniority, and company details, and writes the enriched records back to the row.',
    iconId: 'brand/rb2-b-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rb2b-3',
    blockType: 'rb2b',
    label: 'RB2B LinkedIn phone finder',
    prompt:
        'Create a workflow that takes a list of LinkedIn profile slugs, uses RB2B to look up each prospect\'s mobile phone and best personal email, and writes a ready-to-contact table for outbound calling.',
    iconId: 'brand/rb2-b-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rb2b-4',
    blockType: 'rb2b',
    label: 'RB2B visitor-to-HubSpot sync',
    prompt:
        'Build a workflow that resolves visitor IPs to company domains with RB2B, enriches the matched person into a business profile, and creates or updates the matching contact and company in HubSpot.',
    iconId: 'brand/rb2-b-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rb2b-5',
    blockType: 'rb2b',
    label: 'RB2B visitor Slack alerts',
    prompt:
        'Create a workflow that reads a list of website visitor IPs, uses RB2B to resolve each person and their company, and posts an alert with the identified LinkedIn profile and company to the sales Slack channel.',
    iconId: 'brand/rb2-b-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rb2b-6',
    blockType: 'rb2b',
    label: 'RB2B LinkedIn slug resolver',
    prompt:
        'Build a workflow that takes a first name, last name, and company domain, uses RB2B LinkedIn slug search to resolve the matching profile, and enriches it into a business profile written to a prospect table.',
    iconId: 'brand/rb2-b-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rb2b-7',
    blockType: 'rb2b',
    label: 'RB2B engagement freshness sweep',
    prompt:
        'Create a scheduled workflow that runs my list of prospect emails through RB2B email-to-last-active-date lookups, flags recently active contacts, and logs the engagement snapshot to a table for prioritized follow-up.',
    iconId: 'brand/rb2-b-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rds-0',
    blockType: 'rds',
    label: 'RDS daily metrics digest',
    prompt:
        'Build a scheduled workflow that runs an aggregate SQL query against my Amazon RDS database each morning, summarizes the key numbers with an agent, and posts the digest to Slack.',
    iconId: 'brand/rds-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rds-1',
    blockType: 'rds',
    label: 'RDS natural-language query agent',
    prompt:
        'Create an agent that introspects my Amazon RDS schema, turns plain-English questions into SQL, runs the query through the Data API, and returns the results in a readable answer.',
    iconId: 'brand/rds-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rds-2',
    blockType: 'rds',
    label: 'RDS lead capture',
    prompt:
        'Build a workflow triggered by a form submission that validates the payload and inserts a new lead row into my Amazon RDS database, then confirms the write back to the submitter.',
    iconId: 'brand/rds-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rds-3',
    blockType: 'rds',
    label: 'RDS to spreadsheet export',
    prompt:
        'Create a scheduled workflow that queries Amazon RDS for the latest records, writes the rows into a Sim table, and keeps a running export the operations team can review.',
    iconId: 'brand/rds-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rds-4',
    blockType: 'rds',
    label: 'RDS record updater from Slack',
    prompt:
        'Build a workflow that reads update requests posted in a Slack channel, parses the target record and fields with an agent, and runs the matching UPDATE against Amazon RDS with the conditions applied.',
    iconId: 'brand/rds-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rds-5',
    blockType: 'rds',
    label: 'RDS row-change alerter',
    prompt:
        'Create a scheduled workflow that queries Amazon RDS for rows matching a watch condition, compares them to the previous run stored in a table, and posts a Slack alert when a tracked record changes.',
    iconId: 'brand/rds-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rds-6',
    blockType: 'rds',
    label: 'RDS + BigQuery analytics mirror',
    prompt:
        'Build a scheduled workflow that queries analytical tables from Amazon RDS, loads the rows into BigQuery for downstream BI, and writes a sync log to a table.',
    iconId: 'brand/rds-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'reddit-0',
    blockType: 'reddit',
    label: 'Reddit mention tracker',
    prompt:
        'Create a scheduled workflow that monitors Reddit and X for mentions of my brand and competitors, scores each mention by sentiment and reach, logs them to a table, and sends a daily Slack digest of notable mentions.',
    iconId: 'brand/reddit-icon',
    modules: <String>['tables', 'scheduled', 'agent', 'workflows'],
    providerId: 'reddit',
  ),
  SuggestionTemplate(
    id: 'reddit-1',
    blockType: 'reddit',
    label: 'Reddit subreddit monitor',
    prompt:
        'Build a scheduled workflow that uses Reddit to watch target subreddits for posts matching brand or product keywords, scores each for relevance and sentiment, and posts notable hits to Slack with the original link.',
    iconId: 'brand/reddit-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'reddit',
  ),
  SuggestionTemplate(
    id: 'reddit-2',
    blockType: 'reddit',
    label: 'Reddit user-question knowledge mining',
    prompt:
        'Create a workflow that pulls top questions from Reddit industry subreddits weekly, classifies by theme, and writes a content-opportunity table the marketing team can prioritize.',
    iconId: 'brand/reddit-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'reddit',
  ),
  SuggestionTemplate(
    id: 'reddit-3',
    blockType: 'reddit',
    label: 'Reddit AMA preparer',
    prompt:
        'Build a workflow that aggregates top Reddit AMA-style questions for a topic, clusters them, drafts polished answers using a knowledge base, and posts a Q&A document for review.',
    iconId: 'brand/reddit-icon',
    modules: <String>['knowledge-base', 'agent', 'files', 'workflows'],
    providerId: 'reddit',
  ),
  SuggestionTemplate(
    id: 'reddit-4',
    blockType: 'reddit',
    label: 'Reddit competitor watch',
    prompt:
        'Create a scheduled workflow that monitors Reddit threads mentioning competitors weekly, summarizes sentiment and pain points, and writes a competitive intelligence note to a tracking table.',
    iconId: 'brand/reddit-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'reddit',
  ),
  SuggestionTemplate(
    id: 'reddit-5',
    blockType: 'reddit',
    label: 'Reddit crisis-signal alerter',
    prompt:
        'Build a scheduled workflow that polls Reddit for sudden bursts of negative posts about the brand, classifies severity, and pages the PR team via Slack and PagerDuty when a real crisis emerges.',
    iconId: 'brand/reddit-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'reddit',
  ),
  SuggestionTemplate(
    id: 'reddit-6',
    blockType: 'reddit',
    label: 'Reddit content-idea collector',
    prompt:
        'Create a scheduled workflow that polls marketing-relevant Reddit subreddits, captures upvoted long-form posts, summarizes each, and adds them to a content-ideas table with effort and impact scores.',
    iconId: 'brand/reddit-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'reddit',
  ),
  SuggestionTemplate(
    id: 'redis-0',
    blockType: 'redis',
    label: 'Redis response cache',
    prompt:
        'Build a workflow that checks Redis for a cached result by key before running an expensive step, and writes the computed result back with a TTL when there is a miss so repeat requests stay fast.',
    iconId: 'brand/redis-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'redis-1',
    blockType: 'redis',
    label: 'Redis rate limiter',
    prompt:
        'Create a workflow that increments a per-user Redis counter on each request, sets an expiry on the first hit, and blocks the request when the counter passes the allowed threshold within the window.',
    iconId: 'brand/redis-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'redis-2',
    blockType: 'redis',
    label: 'Redis feature-flag reader',
    prompt:
        'Build a workflow that reads feature-flag values from a Redis hash, branches downstream logic on whether each flag is enabled, and falls back to a default when a flag key is missing.',
    iconId: 'brand/redis-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'redis-3',
    blockType: 'redis',
    label: 'Redis job queue worker',
    prompt:
        'Create a scheduled workflow that pops the next job off a Redis list, processes it with an agent, and writes the outcome to a table so a backlog of work is drained on an interval.',
    iconId: 'brand/redis-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'redis-4',
    blockType: 'redis',
    label: 'Redis cache warmer',
    prompt:
        'Build a scheduled workflow that reads a list of hot keys from a table and sets each one in Redis with fresh values and a TTL, so popular lookups stay warm.',
    iconId: 'brand/redis-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'redis-5',
    blockType: 'redis',
    label: 'Redis daily counter digest',
    prompt:
        'Create a scheduled workflow that reads the day’s Redis counters by key pattern, builds a summary of the totals with an agent, and posts the digest to Slack.',
    iconId: 'brand/redis-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'redis-6',
    blockType: 'redis',
    label: 'Redis session lookup',
    prompt:
        'Build a workflow that reads a session hash from Redis by token, returns the stored user context to the caller, and refreshes the key’s expiry so active sessions stay alive.',
    iconId: 'brand/redis-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'reducto-0',
    blockType: 'reducto',
    label: 'Reducto contract parser',
    prompt:
        'Create a workflow that uses Reducto to parse uploaded contract PDFs into structured clauses, writes payment terms, liability caps, and termination conditions to a table, and flags non-standard clauses.',
    iconId: 'brand/reducto-icon',
    modules: <String>['tables', 'files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'reducto-1',
    blockType: 'reducto',
    label: 'Reducto + knowledge base loader',
    prompt:
        'Build a workflow that parses every PDF in a Drive folder with Reducto, normalizes the structure, and upserts chunks into a knowledge base with section-aware metadata so retrieval returns the right passage.',
    iconId: 'brand/reducto-icon',
    modules: <String>['knowledge-base', 'files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'reducto-2',
    blockType: 'reducto',
    label: 'Reducto medical-record digester',
    prompt:
        'Build a workflow that parses medical record PDFs with Reducto, extracts diagnoses, medications, and visit summaries to structured rows, and produces a patient-facing one-pager file.',
    iconId: 'brand/reducto-icon',
    modules: <String>['tables', 'files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'reducto-3',
    blockType: 'reducto',
    label: 'Reducto + Mem0 contract memory',
    prompt:
        'Create a workflow that parses contracts with Reducto and writes the key terms into Mem0 per counterparty, so future interactions reference the real contract terms.',
    iconId: 'brand/reducto-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'reducto-4',
    blockType: 'reducto',
    label: 'Reducto invoice line-item extractor',
    prompt:
        'Build a workflow that parses incoming invoice PDFs with Reducto, extracts vendor, line items, tax, and totals into an accounts-payable table, and flags any invoice that fails to reconcile against its purchase order.',
    iconId: 'brand/reducto-icon',
    modules: <String>['files', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'reducto-5',
    blockType: 'reducto',
    label: 'Reducto financial-statement digitizer',
    prompt:
        'Create a workflow that parses quarterly financial-statement PDFs with Reducto, extracts the balance sheet and income statement figures into structured rows, and writes a normalized table the finance team can chart over time.',
    iconId: 'brand/reducto-icon',
    modules: <String>['files', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'reducto-6',
    blockType: 'reducto',
    label: 'Reducto form-intake router',
    prompt:
        'Build a workflow that runs each uploaded intake form through Reducto, extracts the applicant fields into a table, and routes the parsed submission to the right reviewer in Slack based on the form type.',
    iconId: 'brand/reducto-icon',
    modules: <String>['files', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'resend-0',
    blockType: 'resend',
    label: 'Resend + Loops onboarding emails',
    prompt:
        'Build a workflow that listens for new signups, creates a Loops contact with the right user group, and sends the welcome email through Resend with a personalized subject and body so the first impression is on-brand and fast.',
    iconId: 'brand/resend-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'resend-1',
    blockType: 'resend',
    label: 'Resend domain monitor',
    prompt:
        'Create a scheduled workflow that lists Resend domains, checks DNS verification status for each, and posts a Slack alert the moment any domain shows a verification or DKIM problem so we never silently lose deliverability.',
    iconId: 'brand/resend-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'resend-2',
    blockType: 'resend',
    label: 'Resend transactional flow',
    prompt:
        'Build a workflow that listens for product events, renders the right transactional email body, sends it through Resend, then retrieves the message status after a short delay and writes delivery, open, and click events to a per-user activity table.',
    iconId: 'brand/resend-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'resend-3',
    blockType: 'resend',
    label: 'Resend + AgentMail reply handler',
    prompt:
        'Create a workflow that sends outbound messages through Resend but routes replies into a per-customer AgentMail inbox, threads them with the original send, and posts unread inbox digests to the support owner.',
    iconId: 'brand/resend-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'resend-4',
    blockType: 'resend',
    label: 'Resend marketing broadcast',
    prompt:
        'Build a workflow that takes a marketing message and a Resend audience, splits the recipient list into safe-volume batches, sends each batch through Resend with rate-limit pacing, and logs per-batch send results to a table.',
    iconId: 'brand/resend-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'resend-5',
    blockType: 'resend',
    label: 'Resend audience sync',
    prompt:
        'Create a workflow that reads my subscriber list from a table, creates or updates each Resend contact in the matching audience, and removes contacts that have unsubscribed by deleting them so the Resend audience stays in sync with my source of truth.',
    iconId: 'brand/resend-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'resend-6',
    blockType: 'resend',
    label: 'Resend unsubscribe handler',
    prompt:
        'Build a workflow that listens for unsubscribe events, looks up the matching Resend contact, updates it to unsubscribed, logs the opt-out reason to a table, and sends a confirmation email through Resend acknowledging the change.',
    iconId: 'brand/resend-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'revenuecat-0',
    blockType: 'revenuecat',
    label: 'RevenueCat MRR dashboard',
    prompt:
        'Build a scheduled daily workflow that pulls RevenueCat subscriber and offering data, calculates MRR, ARPU, and trial-to-paid conversion, logs the metrics to a tracking table with historical trends, and posts a daily Slack summary for the growth team.',
    iconId: 'brand/revenue-cat-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'revenuecat-1',
    blockType: 'revenuecat',
    label: 'RevenueCat entitlement granter',
    prompt:
        'Create a workflow that listens for a customer-success approval — for example a Slack reaction or a row in a table — looks up the RevenueCat subscriber, grants a promotional entitlement with the right expiry, and logs the grant in an audit table for compliance.',
    iconId: 'brand/revenue-cat-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'revenuecat-2',
    blockType: 'revenuecat',
    label: 'RevenueCat renewal recovery',
    prompt:
        'Build a scheduled workflow that lists RevenueCat subscribers with failed renewals, segments them by plan and tenure, drafts a tailored win-back email, sends it via Gmail, and tracks recovery outcomes in a table with retry cadence rules.',
    iconId: 'brand/revenue-cat-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'revenuecat-3',
    blockType: 'revenuecat',
    label: 'RevenueCat attribute sync',
    prompt:
        'Create a workflow that listens for changes in your customer table — like email, display name, or company — and updates the matching RevenueCat subscriber attributes so analytics and targeted offers always reflect the latest customer state.',
    iconId: 'brand/revenue-cat-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'revenuecat-4',
    blockType: 'revenuecat',
    label: 'RevenueCat trial expiry digest',
    prompt:
        'Build a scheduled daily workflow that lists RevenueCat subscribers whose trials expire in the next three days, ranks them by engagement, drafts a personalized conversion nudge, and emails the success team a prioritized list to call.',
    iconId: 'brand/revenue-cat-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'revenuecat-5',
    blockType: 'revenuecat',
    label: 'RevenueCat Google Play refund',
    prompt:
        'Create a workflow that takes a refund approval from a support ticket, calls the RevenueCat Google Play refund operation with the right transaction identifier, revokes access, posts the outcome back on the ticket, and logs the action in a compliance table.',
    iconId: 'brand/revenue-cat-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'revenuecat-6',
    blockType: 'revenuecat',
    label: 'RevenueCat offering report',
    prompt:
        'Build a scheduled weekly workflow that pulls RevenueCat offerings and recent purchases, computes conversion rate per offering and per package, writes a narrative analysis file with recommendations, and Slacks growth leadership the top findings.',
    iconId: 'brand/revenue-cat-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rippling-0',
    blockType: 'rippling',
    label: 'Rippling new-hire provisioning',
    prompt:
        'Build a scheduled workflow that polls Rippling for new workers, creates accounts in the matching downstream tools, drops each new hire into the right Slack channels, books day-one onboarding via Google Calendar, and writes provisioning status to a tracking table.',
    iconId: 'brand/rippling-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rippling-1',
    blockType: 'rippling',
    label: 'Rippling departure offboarder',
    prompt:
        'Create a scheduled workflow that polls Rippling for workers transitioning out, gathers their owned resources, deactivates downstream accounts, schedules data handoff meetings, posts a structured offboarding checklist to a table, and notifies the people team in Slack.',
    iconId: 'brand/rippling-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rippling-2',
    blockType: 'rippling',
    label: 'Rippling org chart export',
    prompt:
        'Build a scheduled weekly workflow that pulls Rippling workers, departments, teams, and titles, writes an updated org chart file, diffs against last week to find structural changes, and Slacks people operations any unexpected moves for review.',
    iconId: 'brand/rippling-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rippling-3',
    blockType: 'rippling',
    label: 'Rippling custom object sync',
    prompt:
        'Create a workflow that reads rows from a Sim table representing custom Rippling objects — perks, equipment, allowances — and upserts them into Rippling so HR can manage company-specific data with the same governance as core worker records.',
    iconId: 'brand/rippling-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rippling-4',
    blockType: 'rippling',
    label: 'Rippling team and title audit',
    prompt:
        'Build a scheduled monthly workflow that lists Rippling teams, titles, and job functions, flags duplicates, unused values, and inconsistent naming, writes a cleanup report file, and opens a Linear task for the people operations owner of each issue.',
    iconId: 'brand/rippling-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rippling-5',
    blockType: 'rippling',
    label: 'Rippling manager change alerts',
    prompt:
        'Create a scheduled workflow that polls Rippling workers for manager reassignments, notifies the worker and the new manager via email, schedules a thirty-minute intro on Google Calendar, and logs the transition in a tracking table for HR visibility.',
    iconId: 'brand/rippling-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rippling-6',
    blockType: 'rippling',
    label: 'Rippling headcount digest',
    prompt:
        'Build a scheduled weekly workflow that pulls Rippling workers grouped by department and employment type, computes headcount, open requisitions, and growth versus the prior week, writes a narrative summary, and emails it to department heads.',
    iconId: 'brand/rippling-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rocketlane-0',
    blockType: 'rocketlane',
    label: 'Rocketlane onboarding kickoff',
    prompt:
        'Build a workflow that creates a Rocketlane project from an onboarding template for a new customer, assigns the implementation manager placeholder, adds the account team as members, and posts a kickoff summary with the project details to Slack.',
    iconId: 'brand/rocketlane-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rocketlane-1',
    blockType: 'rocketlane',
    label: 'Rocketlane status digest',
    prompt:
        'Create a scheduled weekly workflow that lists active Rocketlane projects with their status and due dates, summarizes progress and anything overdue per customer, and emails the digest to the delivery team every Monday morning.',
    iconId: 'brand/rocketlane-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rocketlane-2',
    blockType: 'rocketlane',
    label: 'Rocketlane task escalation',
    prompt:
        'Build a scheduled daily workflow that lists Rocketlane tasks with a due date before today that are not complete, marks them at risk, and posts an escalation to Slack tagging each task name, project, and assignees.',
    iconId: 'brand/rocketlane-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rocketlane-3',
    blockType: 'rocketlane',
    label: 'Rocketlane time rollup',
    prompt:
        'Create a scheduled weekly workflow that searches Rocketlane time entries for the past week, totals billable and non-billable minutes per project, and posts a formatted utilization rollup to Slack.',
    iconId: 'brand/rocketlane-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rocketlane-4',
    blockType: 'rocketlane',
    label: 'Rocketlane invoice monitor',
    prompt:
        'Build a scheduled workflow that lists Rocketlane invoices with an outstanding amount greater than zero and a due date in the past, pulls their payments, and emails the finance team a list of overdue invoices with amounts outstanding.',
    iconId: 'brand/rocketlane-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rocketlane-5',
    blockType: 'rocketlane',
    label: 'Rocketlane allocation report',
    prompt:
        'Create a workflow that lists Rocketlane resource allocations for the next two weeks, writes each member, project, and allocation range into a table, and flags team members who appear in overlapping allocations.',
    iconId: 'brand/rocketlane-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rocketlane-6',
    blockType: 'rocketlane',
    label: 'Rocketlane timesheet reminder',
    prompt:
        'Build a scheduled Friday workflow that lists active Rocketlane team members, searches this week’s time entries per user, and sends a Slack reminder to anyone who has logged less than their expected hours.',
    iconId: 'brand/rocketlane-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rocketlane-7',
    blockType: 'rocketlane',
    label: 'Rocketlane project scaffolding',
    prompt:
        'Create a workflow that scaffolds a delivery project in Rocketlane: create the project, add Discovery, Implementation, and Go-live phases with dates, create kickoff tasks in each phase with assignees, and set up a shared space with a kickoff document.',
    iconId: 'brand/rocketlane-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rootly-0',
    blockType: 'rootly',
    label: 'Rootly incident war-room',
    prompt:
        'Build a scheduled workflow that polls Rootly for newly opened incidents, creates a Slack war-room channel for each, invites responders, posts the incident summary, and keeps the channel topic in sync with severity.',
    iconId: 'brand/rootly-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rootly-1',
    blockType: 'rootly',
    label: 'Rootly retro generator',
    prompt:
        'Create a scheduled workflow that polls Rootly for recently closed incidents, drafts the retrospective doc, pulls the Slack thread and timeline, and assigns owners for follow-up actions in Linear.',
    iconId: 'brand/rootly-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rootly-2',
    blockType: 'rootly',
    label: 'Rootly weekly digest',
    prompt:
        'Build a scheduled weekly workflow that summarizes Rootly incident counts, MTTR, top affected services, and outstanding action items, and posts a digest to leadership Slack.',
    iconId: 'brand/rootly-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rootly-3',
    blockType: 'rootly',
    label: 'Rootly customer-comms drafter',
    prompt:
        'Create a workflow that drafts and queues customer-facing status updates during a Rootly incident based on severity and impacted services, holding for approval before publishing.',
    iconId: 'brand/rootly-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rootly-4',
    blockType: 'rootly',
    label: 'Rootly action-item tracker',
    prompt:
        'Build a workflow that tracks Rootly follow-up actions across incidents, opens Linear tickets, and writes a tables-based dashboard that flags overdue items by owner.',
    iconId: 'brand/rootly-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rootly-5',
    blockType: 'rootly',
    label: 'Rootly on-call digest',
    prompt:
        'Create a scheduled daily workflow that summarizes the past 24 hours of Rootly pages, the on-call responder load by person, and writes a digest to the SRE Slack channel.',
    iconId: 'brand/rootly-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'rootly-6',
    blockType: 'rootly',
    label: 'Rootly + LangSmith agent-incident tracker',
    prompt:
        'Build a workflow that for each Rootly incident involving an AI agent attaches the LangSmith trace, captures the failure mode, and writes the agent-quality regression analysis.',
    iconId: 'brand/rootly-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 's3-0',
    blockType: 's3',
    label: 'S3 report archiver',
    prompt:
        'Build a scheduled workflow that generates a daily report file, uploads it to an S3 bucket under a dated prefix, and posts the object link to Slack so the team always has the latest archived copy.',
    iconId: 'brand/s3-icon',
    modules: <String>['scheduled', 'files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 's3-1',
    blockType: 's3',
    label: 'S3 document ingestion to knowledge base',
    prompt:
        'Create a workflow that lists objects in an S3 bucket, downloads each new document, and indexes it into a Sim knowledge base so agents can answer questions over files stored in S3.',
    iconId: 'brand/s3-icon',
    modules: <String>['files', 'knowledge-base', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 's3-2',
    blockType: 's3',
    label: 'S3 incoming-file processor',
    prompt:
        'Build a workflow that downloads a newly uploaded S3 object, parses its contents, writes the extracted rows to a table, and deletes the source object once processing succeeds.',
    iconId: 'brand/s3-icon',
    modules: <String>['files', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 's3-3',
    blockType: 's3',
    label: 'S3 backup retention sweeper',
    prompt:
        'Create a scheduled workflow that lists objects in an S3 backup bucket, identifies files older than the retention window, deletes the expired objects, and writes a deletion manifest to a table for audit.',
    iconId: 'brand/s3-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 's3-4',
    blockType: 's3',
    label: 'S3 export-to-customer flow',
    prompt:
        'Build a workflow that generates a per-customer data export file, uploads it to a customer-scoped S3 prefix, and emails the customer a download link once the upload completes.',
    iconId: 'brand/s3-icon',
    modules: <String>['files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 's3-5',
    blockType: 's3',
    label: 'S3 bucket inventory dashboard',
    prompt:
        'Create a scheduled workflow that lists objects across an S3 bucket, aggregates object count and total size by prefix, and writes a daily inventory snapshot to a table for cost and growth tracking.',
    iconId: 'brand/s3-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 's3-6',
    blockType: 's3',
    label: 'S3 media-asset publisher',
    prompt:
        'Build a workflow that takes a generated image or document, uploads it to a public S3 bucket, retrieves the object URL, and writes the link back to the originating row in a table.',
    iconId: 'brand/s3-icon',
    modules: <String>['files', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sailpoint-0',
    blockType: 'sailpoint',
    label: 'SailPoint joiner access review',
    prompt:
        'Create a scheduled workflow that lists recent SailPoint account activities for joiners, summarizes their granted access and time-to-access, and posts a digest to Slack for the identity team.',
    iconId: 'brand/sail-point-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sailpoint-1',
    blockType: 'sailpoint',
    label: 'SailPoint access request bot',
    prompt:
        'Build a Slack bot where a user describes the access they need, the agent searches SailPoint entitlements and access profiles, and submits a SailPoint access request on their behalf with a correlation note in client metadata.',
    iconId: 'brand/sail-point-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sailpoint-2',
    blockType: 'sailpoint',
    label: 'SailPoint orphan account finder',
    prompt:
        'Create a scheduled workflow that lists SailPoint accounts using the uncorrelated filter, groups the orphaned accounts by source, and writes the review-ready inventory to a table.',
    iconId: 'brand/sail-point-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sailpoint-3',
    blockType: 'sailpoint',
    label: 'SailPoint certification progress digest',
    prompt:
        'Build a scheduled workflow that lists active SailPoint campaigns and certifications, computes completion percentages, and emails a progress digest to certification owners.',
    iconId: 'brand/sail-point-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sailpoint-4',
    blockType: 'sailpoint',
    label: 'SailPoint leaver access revocation',
    prompt:
        'Create a workflow that, given a departing employee, searches their SailPoint identity access, and submits revoke access requests for each directly-assigned entitlement with a comment referencing the offboarding ticket in Jira.',
    iconId: 'brand/sail-point-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sailpoint-5',
    blockType: 'sailpoint',
    label: 'SailPoint entitlement catalog export',
    prompt:
        'Build a scheduled workflow that lists SailPoint entitlements and their owning sources, and writes the catalog to a table for access-governance reporting.',
    iconId: 'brand/sail-point-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sailpoint-6',
    blockType: 'sailpoint',
    label: 'SailPoint privileged access watch',
    prompt:
        'Create a scheduled workflow that searches SailPoint identities holding privileged roles, cross-references recent account activities, and flags any new privileged grants to a security review channel.',
    iconId: 'brand/sail-point-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'salesforce-0',
    blockType: 'salesforce',
    label: 'Salesforce knowledge search',
    prompt:
        'Create a knowledge base connected to my Salesforce account so all deals, contacts, notes, and activities are automatically synced and searchable. Then build an agent I can ask things like "what\'s the history with Acme Corp?" or "who was involved in the last enterprise deal?" and get instant answers with CRM record citations.',
    iconId: 'brand/salesforce-icon',
    modules: <String>['knowledge-base', 'agent'],
    providerId: 'salesforce',
  ),
  SuggestionTemplate(
    id: 'salesforce-1',
    blockType: 'salesforce',
    label: 'Salesforce pipeline tracker',
    prompt:
        'Create a table with columns for deal name, stage, amount, close date, and next steps. Build a workflow that syncs open deals from Salesforce into this table daily, and sends me a Slack summary each morning of deals that need attention or are at risk of slipping.',
    iconId: 'brand/salesforce-icon',
    modules: <String>['tables', 'scheduled', 'agent', 'workflows'],
    providerId: 'salesforce',
  ),
  SuggestionTemplate(
    id: 'salesforce-2',
    blockType: 'salesforce',
    label: 'Push Salesforce pipeline updates to Slack',
    prompt:
        'Build a workflow that monitors Salesforce opportunities and posts a Slack notification to your sales team whenever a deal advances, closes, or needs immediate attention.',
    iconId: 'brand/salesforce-icon',
    modules: <String>['agent', 'workflows'],
    featured: true,
    providerId: 'salesforce',
  ),
  SuggestionTemplate(
    id: 'salesforce-3',
    blockType: 'salesforce',
    label: 'Salesforce lead router',
    prompt:
        'Build a workflow that triggers on new inbound form submissions, creates a Salesforce lead with the captured fields, runs a SOQL query to check for an existing account match, assigns the lead to the right owner, and posts the new lead with its score to Slack.',
    iconId: 'brand/salesforce-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'salesforce',
  ),
  SuggestionTemplate(
    id: 'salesforce-4',
    blockType: 'salesforce',
    label: 'Salesforce case escalation',
    prompt:
        'Create a scheduled workflow that queries open Salesforce cases past their SLA, escalates each by updating its priority and owner, creates a follow-up task on the account, and Slacks the support lead a summary of everything that breached.',
    iconId: 'brand/salesforce-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'salesforce',
  ),
  SuggestionTemplate(
    id: 'salesforce-5',
    blockType: 'salesforce',
    label: 'Salesforce report digest',
    prompt:
        'Build a scheduled workflow that runs a saved Salesforce report each morning, refreshes the linked dashboard, summarizes the key metrics and biggest movers with an agent, and emails the leadership team a written narrative of what changed.',
    iconId: 'brand/salesforce-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'salesforce',
  ),
  SuggestionTemplate(
    id: 'salesforce-6',
    blockType: 'salesforce',
    label: 'Salesforce onboarding kickoff',
    prompt:
        'Create a workflow that watches Salesforce opportunities for stage changes to closed-won, pulls the related account and contacts, creates onboarding tasks for the CS owner, and writes a kickoff record into a tables-based project tracker.',
    iconId: 'brand/salesforce-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'salesforce',
  ),
  SuggestionTemplate(
    id: 'sap_concur-0',
    blockType: 'sap_concur',
    label: 'SAP Concur expense classifier',
    prompt:
        'Build a scheduled workflow that polls SAP Concur for newly submitted expense reports, classifies each line item, validates against policy, and routes exceptions to the approver in Slack.',
    iconId: 'brand/sap-concur-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sap_concur-1',
    blockType: 'sap_concur',
    label: 'SAP Concur policy auditor',
    prompt:
        'Create a scheduled monthly workflow that audits SAP Concur expense reports against policy, flags pattern violations by employee, and writes a compliance report.',
    iconId: 'brand/sap-concur-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sap_concur-2',
    blockType: 'sap_concur',
    label: 'SAP Concur travel pre-approval',
    prompt:
        'Build a scheduled workflow that polls SAP Concur for pending travel requests, routes each to the right approver based on amount and destination, captures the decision over Microsoft Teams, and moves the request to the approved or sent-back state.',
    iconId: 'brand/sap-concur-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sap_concur-3',
    blockType: 'sap_concur',
    label: 'SAP Concur receipt OCR',
    prompt:
        'Create a workflow that processes SAP Concur receipt images with AWS Textract, validates the extracted vendor and amount against the report line, and flags mismatches.',
    iconId: 'brand/sap-concur-icon',
    modules: <String>['files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sap_concur-4',
    blockType: 'sap_concur',
    label: 'SAP Concur reimbursement chaser',
    prompt:
        'Build a scheduled workflow that finds SAP Concur reports stuck pending more than 7 days, sends the approver a reminder, and writes the chase log to a table.',
    iconId: 'brand/sap-concur-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sap_concur-5',
    blockType: 'sap_concur',
    label: 'SAP Concur travel reconciler',
    prompt:
        'Create a workflow that reconciles SAP Concur travel bookings with corporate card transactions, flags missing receipts, and writes a reconciliation table for finance.',
    iconId: 'brand/sap-concur-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sap_concur-6',
    blockType: 'sap_concur',
    label: 'SAP Concur budget watcher',
    prompt:
        'Build a scheduled monthly workflow that aggregates SAP Concur spend per department, compares against budget, and pings managers in Teams when overspend is projected.',
    iconId: 'brand/sap-concur-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sap_s4hana-0',
    blockType: 'sap_s4hana',
    label: 'SAP business partner sync',
    prompt:
        'Build a workflow that takes new customer rows from a CRM-backed table and creates or updates SAP S/4HANA business partners via the API_BUSINESS_PARTNER service, mapping person and organization categories correctly so finance and sales stay aligned.',
    iconId: 'brand/sap-s4-hana-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sap_s4hana-1',
    blockType: 'sap_s4hana',
    label: 'SAP sales order monitor',
    prompt:
        'Create a scheduled workflow that lists open SAP S/4HANA sales orders, flags orders past their expected delivery date, summarizes top blockers, logs them to a tracking table, and emails the operations leads a daily prioritized list.',
    iconId: 'brand/sap-s4-hana-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sap_s4hana-2',
    blockType: 'sap_s4hana',
    label: 'SAP supplier invoice intake',
    prompt:
        'Build a workflow that ingests inbound supplier invoice PDFs from Gmail, extracts header and line-item data with an agent, validates the vendor against SAP S/4HANA suppliers, creates the supplier invoice via OData, and writes the outcome to a finance audit table.',
    iconId: 'brand/sap-s4-hana-icon',
    modules: <String>['files', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sap_s4hana-3',
    blockType: 'sap_s4hana',
    label: 'SAP billing reconciliation',
    prompt:
        'Create a scheduled workflow that pulls SAP S/4HANA billing documents, joins them against your CRM revenue table, flags mismatches in amounts or customers, and emails finance a reconciliation report file with the specific rows to investigate.',
    iconId: 'brand/sap-s4-hana-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sap_s4hana-4',
    blockType: 'sap_s4hana',
    label: 'SAP delivery exception alerts',
    prompt:
        'Build a workflow that runs every hour, lists SAP S/4HANA outbound and inbound deliveries with delays or missing reference documents, classifies the exception, posts a Slack alert to the operations channel, and updates a remediation tracking table.',
    iconId: 'brand/sap-s4-hana-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sap_s4hana-5',
    blockType: 'sap_s4hana',
    label: 'SAP stock-level digest',
    prompt:
        'Create a scheduled daily workflow that queries SAP S/4HANA for product stock and material document movements, identifies SKUs trending toward stock-out, writes a prioritized digest file, and Slacks the supply chain team for action.',
    iconId: 'brand/sap-s4-hana-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sap_s4hana-6',
    blockType: 'sap_s4hana',
    label: 'SAP purchase requisition router',
    prompt:
        'Build a workflow exposed to internal users as a form that captures purchase requisition details, classifies the request, creates the requisition in SAP S/4HANA via OData, posts the requisition number back to the requester, and logs the request in a tracking table.',
    iconId: 'brand/sap-s4-hana-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'secrets_manager-0',
    blockType: 'secrets_manager',
    label: 'Secrets Manager scheduled rotation',
    prompt:
        'Build a scheduled workflow that lists AWS Secrets Manager secrets, generates a new value for each secret past its rotation window, updates it with the new value, and writes the rotation status to a compliance table.',
    iconId: 'brand/secrets-manager-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'secrets_manager-1',
    blockType: 'secrets_manager',
    label: 'Secrets Manager inventory auditor',
    prompt:
        'Create a scheduled workflow that lists all AWS Secrets Manager secrets, flags ones missing descriptions or older than a chosen age, writes a security review, and posts the findings to Slack.',
    iconId: 'brand/secrets-manager-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'secrets_manager-2',
    blockType: 'secrets_manager',
    label: 'Secrets Manager stale-secret cleaner',
    prompt:
        'Build a scheduled workflow that lists AWS Secrets Manager secrets, identifies ones created before a chosen cutoff, requests owner approval in Slack, deletes the approved secrets, and writes the cleanup audit.',
    iconId: 'brand/secrets-manager-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'secrets_manager-3',
    blockType: 'secrets_manager',
    label: 'Secrets Manager + Infisical mirror',
    prompt:
        'Create a workflow that mirrors secrets between AWS Secrets Manager and Infisical for cross-cloud applications, normalizes naming, and writes a sync log.',
    iconId: 'brand/secrets-manager-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'secrets_manager-4',
    blockType: 'secrets_manager',
    label: 'Secrets Manager break-glass retrieval',
    prompt:
        'Build a workflow that gates retrieval of a sensitive AWS Secrets Manager secret behind a Slack approval, captures the requester and justification, fetches the secret only after sign-off, and writes the audit record.',
    iconId: 'brand/secrets-manager-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'secrets_manager-5',
    blockType: 'secrets_manager',
    label: 'Secrets Manager + 1Password bridge',
    prompt:
        'Create a workflow that bridges select AWS Secrets Manager secrets into 1Password for human-shared credentials while keeping access logs aligned for audit.',
    iconId: 'brand/secrets-manager-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'secrets_manager-6',
    blockType: 'secrets_manager',
    label: 'Secrets Manager change watcher',
    prompt:
        'Build a scheduled workflow that polls AWS Secrets Manager secret version IDs, compares them against a baseline stored in a table, and pings the security Slack channel when a secret changes unexpectedly.',
    iconId: 'brand/secrets-manager-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'secrets_manager-7',
    blockType: 'secrets_manager',
    label: 'Secrets Manager native rotation kickoff',
    prompt:
        'Build a scheduled workflow that describes AWS Secrets Manager secrets nearing their next rotation date, starts native rotation for the ones that are due, and writes the outcome to a compliance table.',
    iconId: 'brand/secrets-manager-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'semrush-0',
    blockType: 'semrush',
    label: 'Semrush rank tracker',
    prompt:
        'Create a scheduled weekly workflow that pulls Semrush domain organic keywords for my site, writes position changes into a table, and posts a Slack summary of the biggest gainers and losers.',
    iconId: 'brand/semrush-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'semrush-1',
    blockType: 'semrush',
    label: 'Semrush content gap finder',
    prompt:
        'Build a workflow that runs a Semrush Domain vs. Domain comparison between my site and two competitors, has an agent pick the keywords they rank for and I do not, and writes a prioritized content brief table.',
    iconId: 'brand/semrush-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'semrush-2',
    blockType: 'semrush',
    label: 'Semrush keyword research assistant',
    prompt:
        'Create a workflow where I submit a seed keyword, Semrush returns related keywords, broad match variations, and questions, and an agent clusters them into topic groups with search volume and difficulty.',
    iconId: 'brand/semrush-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'semrush-3',
    blockType: 'semrush',
    label: 'Semrush backlink monitor',
    prompt:
        'Build a scheduled workflow that pulls new Semrush referring domains for my site weekly, flags any with a high Authority Score, and posts a Slack digest with the linking page and anchor text.',
    iconId: 'brand/semrush-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'semrush-4',
    blockType: 'semrush',
    label: 'Semrush competitor ad watch',
    prompt:
        'Create a scheduled workflow that pulls Semrush domain paid keywords and paid competitors for my top three rivals, diffs them against last week, and emails the growth team a summary of new ad copy and bids.',
    iconId: 'brand/semrush-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'semrush-5',
    blockType: 'semrush',
    label: 'Semrush landing page audit',
    prompt:
        'Build a workflow that reads a list of landing page URLs from a table, pulls the Semrush URL overview and organic keywords for each, and writes traffic and keyword counts back to the table for review.',
    iconId: 'brand/semrush-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'semrush-6',
    blockType: 'semrush',
    label: 'Semrush new competitor alert',
    prompt:
        'Create a monthly workflow that pulls Semrush organic competitors for my domain, compares them against my tracked competitor list, and posts newly surfaced competitors to Slack for review.',
    iconId: 'brand/semrush-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'semrush-7',
    blockType: 'semrush',
    label: 'Semrush + Ahrefs visibility scoreboard',
    prompt:
        'Build a scheduled monthly workflow that joins Semrush domain overview data with Ahrefs backlink metrics, writes a combined visibility scoreboard table, and emails leadership.',
    iconId: 'brand/semrush-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sendblue-0',
    blockType: 'sendblue',
    label: 'Sendblue lead speed-to-text',
    prompt:
        'Build a workflow that fires when a new lead submits a form, drafts a friendly intro, and sends it as an iMessage via Sendblue within seconds so reps reach hot leads while they are still interested.',
    iconId: 'brand/sendblue-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sendblue-1',
    blockType: 'sendblue',
    label: 'Sendblue appointment reminders',
    prompt:
        'Create a scheduled workflow that reads tomorrow\'s appointments from a table and sends each customer a personalized Sendblue iMessage reminder with the time and a reschedule link.',
    iconId: 'brand/sendblue-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sendblue-2',
    blockType: 'sendblue',
    label: 'Sendblue inbound reply autoresponder',
    prompt:
        'Build a workflow triggered when a Sendblue message is received that classifies the inbound text, drafts a context-aware reply with an agent, and sends it back to the same number as an iMessage.',
    iconId: 'brand/sendblue-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sendblue-3',
    blockType: 'sendblue',
    label: 'Sendblue iMessage vs SMS routing',
    prompt:
        'Create a workflow that evaluates whether a recipient number supports iMessage with Sendblue, then sends a rich iMessage when supported or a plain SMS fallback otherwise.',
    iconId: 'brand/sendblue-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sendblue-4',
    blockType: 'sendblue',
    label: 'Sendblue order-status notifier',
    prompt:
        'Create a workflow triggered when an order ships that looks up the customer phone number and sends a Sendblue iMessage with the tracking number and estimated delivery date.',
    iconId: 'brand/sendblue-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sendblue-5',
    blockType: 'sendblue',
    label: 'Sendblue delivery-failure alerts',
    prompt:
        'Build a workflow triggered by a Sendblue message status update that, when the status is ERROR, posts the failing number and error message to a Slack channel so the team can follow up.',
    iconId: 'brand/sendblue-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sendblue-6',
    blockType: 'sendblue',
    label: 'Sendblue group broadcast',
    prompt:
        'Create a workflow that reads a list of VIP customers from a table and sends them a single Sendblue group iMessage announcing a new product launch with an image attachment.',
    iconId: 'brand/sendblue-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sendblue-7',
    blockType: 'sendblue',
    label: 'Sendblue conversational support agent',
    prompt:
        'Build a workflow triggered on inbound Sendblue messages that shows a typing indicator, looks up the customer in a table, answers their question with an agent, and replies over iMessage.',
    iconId: 'brand/sendblue-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sendgrid-0',
    blockType: 'sendgrid',
    label: 'SendGrid transactional pipeline',
    prompt:
        'Build a workflow that listens for product events from my tables — signup, password reset, receipt — picks the matching SendGrid dynamic template, populates the variables, sends the email, and writes the message ID back to the table for audit.',
    iconId: 'brand/sendgrid-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sendgrid-1',
    blockType: 'sendgrid',
    label: 'SendGrid send-failure monitor',
    prompt:
        'Create a workflow that sends emails through SendGrid, logs each send result and any error to a delivery table, and posts a Slack alert summarizing failure patterns by recipient domain and template when the failure rate crosses a threshold.',
    iconId: 'brand/sendgrid-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sendgrid-2',
    blockType: 'sendgrid',
    label: 'SendGrid + Resend failover',
    prompt:
        'Build a workflow that sends transactional emails through SendGrid by default and automatically falls back to Resend when the primary send fails or rate limits, logging every send and the provider used to a delivery table.',
    iconId: 'brand/sendgrid-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sendgrid-3',
    blockType: 'sendgrid',
    label: 'SendGrid contact list cleaner',
    prompt:
        'Create a scheduled workflow that searches SendGrid marketing contacts for invalid or duplicate entries, removes the bad addresses, merges duplicates, and writes a cleanup report to a tracking table.',
    iconId: 'brand/sendgrid-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sendgrid-4',
    blockType: 'sendgrid',
    label: 'SendGrid + SES enterprise sender',
    prompt:
        'Build a workflow that splits transactional traffic between SendGrid and AWS SES based on message category and recipient region, balances volume to stay under per-provider limits, and writes provider, status, and latency to a delivery table.',
    iconId: 'brand/sendgrid-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sendgrid-5',
    blockType: 'sendgrid',
    label: 'SendGrid + Mailgun send scorecard',
    prompt:
        'Create a scheduled weekly workflow that sends categorized test messages through both SendGrid and Mailgun, records each provider response, latency, and error to a delivery table, and generates a scorecard file recommending which provider to use per send category.',
    iconId: 'brand/sendgrid-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sendgrid-6',
    blockType: 'sendgrid',
    label: 'SendGrid segmented list builder',
    prompt:
        'Build a workflow that reads a freshly scored audience from a table, creates a new SendGrid marketing list, adds each matching contact to the list, and removes anyone who no longer qualifies so the segment is ready for the next campaign send.',
    iconId: 'brand/sendgrid-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sentry-0',
    blockType: 'sentry',
    label: 'Sentry on-call triage agent',
    prompt:
        'Build an agent that monitors Sentry for new errors, automatically triages them by severity and affected users, creates Linear tickets for critical issues with full stack traces, and sends a Slack notification to the on-call channel.',
    iconId: 'emcn/bug',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sentry-1',
    blockType: 'sentry',
    label: 'Sentry error triage',
    prompt:
        'Build a scheduled workflow that polls Sentry for new unresolved issues, classifies severity, groups similar issues, creates a Linear ticket on first occurrence above the threshold, and pings the owning team in Slack.',
    iconId: 'brand/sentry-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sentry-2',
    blockType: 'sentry',
    label: 'Sentry release health gate',
    prompt:
        'Create a workflow that runs after a Vercel deploy, checks Sentry release health, and rolls back the deploy if the error rate exceeds the threshold, posting an alert to Slack.',
    iconId: 'brand/sentry-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sentry-3',
    blockType: 'sentry',
    label: 'Sentry weekly regression brief',
    prompt:
        'Build a scheduled weekly workflow that compares Sentry error rates week-over-week, identifies top regressors, and writes a brief to engineering leadership in Slack.',
    iconId: 'brand/sentry-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sentry-4',
    blockType: 'sentry',
    label: 'Sentry source-map verifier',
    prompt:
        'Create a scheduled workflow that scans Sentry for issues with missing or stale source maps, writes a tracking table, and opens Linear tickets for the worst offenders.',
    iconId: 'brand/sentry-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sentry-5',
    blockType: 'sentry',
    label: 'Sentry customer-impact mapper',
    prompt:
        'Build a workflow that takes a Sentry issue and matches affected users to CRM accounts, scoring customer impact, and creates a customer-facing incident note in HubSpot for the worst-affected accounts.',
    iconId: 'brand/sentry-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sentry-6',
    blockType: 'sentry',
    label: 'Sentry release tracker on deploy',
    prompt:
        'Create a workflow that watches GitHub for merges to main, creates a new Sentry release with the commit range, marks the deploy in Sentry for the production environment, and posts the release notes and linked issues to Slack so the team knows what shipped.',
    iconId: 'brand/sentry-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'serper-0',
    blockType: 'serper',
    label: 'Serper SERP digest',
    prompt:
        'Build a scheduled daily workflow that runs Serper searches for tracked keywords, writes the SERP positions of my domain into a tables-based SEO log, and pings on changes.',
    iconId: 'brand/serper-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'serper-1',
    blockType: 'serper',
    label: 'Serper competitor SERP watcher',
    prompt:
        'Create a workflow that runs Serper searches for competitor keywords weekly, captures top SERP entries, and writes a competitive SEO digest to Slack.',
    iconId: 'brand/serper-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'serper-2',
    blockType: 'serper',
    label: 'Serper news monitor',
    prompt:
        'Build a scheduled workflow that uses Serper news search for brand keywords, classifies each result, and posts notable mentions to a Slack PR channel.',
    iconId: 'brand/serper-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'serper-3',
    blockType: 'serper',
    label: 'Serper local-pack tracker',
    prompt:
        'Create a workflow that uses Serper to track Google local-pack rankings for tracked queries by city, writes the results to a tables-based SEO log, and surfaces wins.',
    iconId: 'brand/serper-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'serper-4',
    blockType: 'serper',
    label: 'Serper research agent',
    prompt:
        'Build an agent that uses Serper as a primary web-search tool, returns answers with citations, and saves long-form research to a knowledge base.',
    iconId: 'brand/serper-icon',
    modules: <String>['agent', 'knowledge-base', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'serper-5',
    blockType: 'serper',
    label: 'Serper image-search collector',
    prompt:
        'Create a workflow that uses Serper image search for brand or product mentions, captures unique image URLs into a table, and flags potential trademark misuse.',
    iconId: 'brand/serper-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'serper-6',
    blockType: 'serper',
    label: 'Serper geo-SERP comparator',
    prompt:
        'Build a scheduled workflow that runs Serper across multiple regions for the same keywords, identifies geo-relevant ranking differences, and writes the analysis to a file.',
    iconId: 'brand/serper-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'servicenow-0',
    blockType: 'servicenow',
    label: 'ServiceNow incident commander',
    prompt:
        'Build a workflow triggered when a ServiceNow incident is created at P1 or P2 that opens a Slack war-room channel, posts the incident description and impacted CI, invites the assignment group, and keeps the channel topic in sync with the incident state.',
    iconId: 'brand/service-now-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'servicenow-1',
    blockType: 'servicenow',
    label: 'ServiceNow change request analyzer',
    prompt:
        'Create a workflow that reads new ServiceNow change requests, scores risk based on affected services, blackout windows, and change history, and updates the change record with a recommended approver chain and a risk justification note.',
    iconId: 'brand/service-now-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'servicenow-2',
    blockType: 'servicenow',
    label: 'ServiceNow knowledge sync',
    prompt:
        'Build a scheduled workflow that pulls Confluence pages tagged for IT operations and creates or updates matching ServiceNow knowledge articles, mapping categories and authors so the knowledge base stays in sync without manual copy-paste.',
    iconId: 'brand/service-now-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'servicenow-3',
    blockType: 'servicenow',
    label: 'ServiceNow asset audit',
    prompt:
        'Create a scheduled workflow that queries the ServiceNow CMDB for assets missing owner, lifecycle, or last-discovered fields, flags stale or orphaned records in a tracking table, and opens remediation tasks against the responsible group.',
    iconId: 'brand/service-now-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'servicenow-4',
    blockType: 'servicenow',
    label: 'ServiceNow ticket auto-classifier',
    prompt:
        'Build a workflow triggered by new ServiceNow incidents that classifies category and subcategory, sets impact and urgency, infers the affected service from the description, and routes the ticket to the right assignment group.',
    iconId: 'brand/service-now-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'servicenow-5',
    blockType: 'servicenow',
    label: 'ServiceNow weekly ops digest',
    prompt:
        'Create a scheduled weekly workflow that pulls ServiceNow incident, change, and request data, calculates MTTR, change success rate, and top failing services, and posts a digest to Slack with the standout records linked.',
    iconId: 'brand/service-now-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'servicenow-6',
    blockType: 'servicenow',
    label: 'ServiceNow ticket deflection bot',
    prompt:
        'Build a Slack bot that lets employees report IT issues in natural language, reads similar resolved ServiceNow records to suggest a fix first, and only creates a new ServiceNow incident record with the right category when self-service does not resolve it.',
    iconId: 'brand/service-now-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ses-0',
    blockType: 'ses',
    label: 'SES bulk announcement',
    prompt:
        'Create a workflow that takes a recipient list from a table and an SES email template, sends the announcement using SES bulk send with per-recipient template data, and writes the per-recipient send status back to the table.',
    iconId: 'brand/ses-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ses-1',
    blockType: 'ses',
    label: 'SES verified-identity audit',
    prompt:
        'Build a scheduled workflow that lists AWS SES verified identities, checks the account sending quota and reputation, and posts a Slack report when any identity is unverified or the account approaches the daily quota.',
    iconId: 'brand/ses-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ses-2',
    blockType: 'ses',
    label: 'SES templated nurture',
    prompt:
        'Create a workflow that walks each contact in a tables-based nurture sequence through staged SES templated sends with delays between steps, branches on open or click, and stops the sequence when the contact replies.',
    iconId: 'brand/ses-icon',
    modules: <String>['tables', 'scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ses-3',
    blockType: 'ses',
    label: 'SES + Mailgun multi-region sender',
    prompt:
        'Build a workflow that routes transactional emails through SES in primary regions and through Mailgun for regions where SES is not provisioned, normalizing template variables and writing one unified send log to a table.',
    iconId: 'brand/ses-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ses-4',
    blockType: 'ses',
    label: 'SES + AgentMail customer concierge',
    prompt:
        'Create a workflow that sends outbound customer messages through AWS SES but provisions a per-customer AgentMail inbox to receive replies, threads conversations across both, and tags AgentMail threads with the customer ID.',
    iconId: 'brand/ses-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ses-5',
    blockType: 'ses',
    label: 'SES suppression list sync',
    prompt:
        'Build a workflow that reads bounce and complaint webhook events, adds the affected addresses to the SES account suppression list with the matching reason, and periodically lists suppressed destinations to reconcile a marketing contacts table so unreachable addresses are excluded from future sends.',
    iconId: 'brand/ses-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ses-6',
    blockType: 'ses',
    label: 'SES new-domain onboarding',
    prompt:
        'Create a workflow that takes a new sending domain from a table, creates the SES email identity, polls get email identity until DKIM verification succeeds, creates a dedicated configuration set with open and click tracking enabled, and posts the DNS tokens to Slack for the infrastructure team to add.',
    iconId: 'brand/ses-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ses-7',
    blockType: 'ses',
    label: 'SES domain reputation monitor',
    prompt:
        'Build a scheduled daily workflow that pulls SES account sending statistics and per-identity reputation indicators, logs them to a tracking table for trend lines, and flags any identity whose complaint or bounce rate is trending up.',
    iconId: 'brand/ses-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ses-8',
    blockType: 'ses',
    label: 'SES template library sync',
    prompt:
        'Build a workflow that reads my approved email templates from a table, creates or updates each one in AWS SES with create template, lists existing SES templates to detect drift, and deletes templates that have been removed from the table so the SES library stays in sync.',
    iconId: 'brand/ses-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sftp-0',
    blockType: 'sftp',
    label: 'Pull new files from an SFTP folder',
    prompt:
        'Build a workflow that runs on a schedule, lists a remote SFTP drop folder, downloads any new files, and passes their contents into the workflow for processing.',
    iconId: 'emcn/download',
    modules: <String>['scheduled', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sftp-1',
    blockType: 'sftp',
    label: 'Push a generated report to a partner SFTP',
    prompt:
        'Build a workflow that generates a report file and uploads it to a partner SFTP server under a dated remote path.',
    iconId: 'emcn/upload',
    modules: <String>['files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sftp-2',
    blockType: 'sftp',
    label: 'Mirror a local export to SFTP',
    prompt:
        'Build a workflow that lists a remote SFTP directory, compares it to the files produced by an earlier block, and uploads any missing files to keep the remote directory in sync.',
    iconId: 'emcn/server',
    modules: <String>['files', 'scheduled', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sftp-3',
    blockType: 'sftp',
    label: 'Archive and delete old SFTP files',
    prompt:
        'Build a workflow that runs nightly, lists an SFTP directory, downloads files older than a threshold to archive them, and then deletes the originals from the remote server.',
    iconId: 'emcn/trash',
    modules: <String>['scheduled', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sftp-4',
    blockType: 'sftp',
    label: 'Notify Slack when new files land on SFTP',
    prompt:
        'Build a workflow that checks an SFTP inbox folder on a schedule and sends a Slack message listing any new files that have arrived since the last run.',
    iconId: 'emcn/clipboard-list',
    modules: <String>['scheduled', 'files', 'agent'],
  ),
  SuggestionTemplate(
    id: 'sftp-5',
    blockType: 'sftp',
    label: 'Inventory an SFTP directory',
    prompt:
        'Build a workflow that lists a remote SFTP directory with detailed metadata and records the file names, sizes, and timestamps for auditing.',
    iconId: 'emcn/search',
    modules: <String>['files', 'workflows', 'tables'],
  ),
  SuggestionTemplate(
    id: 'sftp-6',
    blockType: 'sftp',
    label: 'Write a manifest file to SFTP',
    prompt:
        'Build a workflow that assembles a manifest of processed records and creates a manifest.txt file on a remote SFTP path so downstream systems know the batch is ready.',
    iconId: 'emcn/file',
    modules: <String>['files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sftp-7',
    blockType: 'sftp',
    label: 'Download an SFTP file and summarize it',
    prompt:
        'Build a workflow that downloads a file from an SFTP server and passes its contents to an agent that summarizes the key points.',
    iconId: 'emcn/download',
    modules: <String>['files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sftp_v2-0',
    blockType: 'sftp_v2',
    label: 'Pull new files from an SFTP folder',
    prompt:
        'Build a workflow that runs on a schedule, lists a remote SFTP drop folder, downloads any new files, and passes their contents into the workflow for processing.',
    iconId: 'emcn/download',
    modules: <String>['scheduled', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sftp_v2-1',
    blockType: 'sftp_v2',
    label: 'Push a generated report to a partner SFTP',
    prompt:
        'Build a workflow that generates a report file and uploads it to a partner SFTP server under a dated remote path.',
    iconId: 'emcn/upload',
    modules: <String>['files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sftp_v2-2',
    blockType: 'sftp_v2',
    label: 'Mirror a local export to SFTP',
    prompt:
        'Build a workflow that lists a remote SFTP directory, compares it to the files produced by an earlier block, and uploads any missing files to keep the remote directory in sync.',
    iconId: 'emcn/server',
    modules: <String>['files', 'scheduled', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sftp_v2-3',
    blockType: 'sftp_v2',
    label: 'Archive and delete old SFTP files',
    prompt:
        'Build a workflow that runs nightly, lists an SFTP directory, downloads files older than a threshold to archive them, and then deletes the originals from the remote server.',
    iconId: 'emcn/trash',
    modules: <String>['scheduled', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sftp_v2-4',
    blockType: 'sftp_v2',
    label: 'Notify Slack when new files land on SFTP',
    prompt:
        'Build a workflow that checks an SFTP inbox folder on a schedule and sends a Slack message listing any new files that have arrived since the last run.',
    iconId: 'emcn/clipboard-list',
    modules: <String>['scheduled', 'files', 'agent'],
  ),
  SuggestionTemplate(
    id: 'sftp_v2-5',
    blockType: 'sftp_v2',
    label: 'Inventory an SFTP directory',
    prompt:
        'Build a workflow that lists a remote SFTP directory with detailed metadata and records the file names, sizes, and timestamps for auditing.',
    iconId: 'emcn/search',
    modules: <String>['files', 'workflows', 'tables'],
  ),
  SuggestionTemplate(
    id: 'sftp_v2-6',
    blockType: 'sftp_v2',
    label: 'Write a manifest file to SFTP',
    prompt:
        'Build a workflow that assembles a manifest of processed records and creates a manifest.txt file on a remote SFTP path so downstream systems know the batch is ready.',
    iconId: 'emcn/file',
    modules: <String>['files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sftp_v2-7',
    blockType: 'sftp_v2',
    label: 'Download an SFTP file and summarize it',
    prompt:
        'Build a workflow that downloads a file from an SFTP server and passes its contents to an agent that summarizes the key points.',
    iconId: 'emcn/download',
    modules: <String>['files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sharepoint-0',
    blockType: 'sharepoint',
    label: 'SharePoint policy publisher',
    prompt:
        'Build a workflow that turns a Google Docs policy update into a published SharePoint page, posts the change diff to the policies team in Microsoft Teams, and writes the version history.',
    iconId: 'brand/microsoft-sharepoint-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'sharepoint',
  ),
  SuggestionTemplate(
    id: 'sharepoint-1',
    blockType: 'sharepoint',
    label: 'SharePoint stale-page sweeper',
    prompt:
        'Create a scheduled workflow that lists SharePoint pages not updated in 180 days, opens an owner-review thread in Teams, and archives pages once the owner approves.',
    iconId: 'brand/microsoft-sharepoint-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'sharepoint',
  ),
  SuggestionTemplate(
    id: 'sharepoint-2',
    blockType: 'sharepoint',
    label: 'SharePoint knowledge agent',
    prompt:
        'Build an agent that indexes SharePoint sites into a knowledge base, answers internal questions with cited links, and deploys as a Teams chat endpoint.',
    iconId: 'brand/microsoft-sharepoint-icon',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
    providerId: 'sharepoint',
  ),
  SuggestionTemplate(
    id: 'sharepoint-3',
    blockType: 'sharepoint',
    label: 'SharePoint external-share audit',
    prompt:
        'Create a scheduled workflow that audits SharePoint external sharing, flags items above the sensitivity threshold, and posts a security report to Teams compliance channel.',
    iconId: 'brand/microsoft-sharepoint-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'sharepoint',
  ),
  SuggestionTemplate(
    id: 'sharepoint-4',
    blockType: 'sharepoint',
    label: 'SharePoint onboarding hub',
    prompt:
        'Build a workflow triggered by a new hire in Workday that creates a personalized SharePoint onboarding hub with role-relevant docs and shares it with the hire and their manager.',
    iconId: 'brand/microsoft-sharepoint-icon',
    modules: <String>['files', 'agent', 'workflows'],
    providerId: 'sharepoint',
  ),
  SuggestionTemplate(
    id: 'sharepoint-5',
    blockType: 'sharepoint',
    label: 'SharePoint search-relevance auditor',
    prompt:
        'Create a scheduled workflow that runs benchmark queries against SharePoint search weekly, scores the top result relevance, and writes a quality report to Teams.',
    iconId: 'brand/microsoft-sharepoint-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'sharepoint',
  ),
  SuggestionTemplate(
    id: 'sharepoint-6',
    blockType: 'sharepoint',
    label: 'SharePoint to Confluence migrator',
    prompt:
        'Build a workflow that imports SharePoint pages into Confluence under matching spaces, preserves attachments, and writes a mapping table so links can be redirected.',
    iconId: 'brand/microsoft-sharepoint-icon',
    modules: <String>['files', 'tables', 'agent', 'workflows'],
    providerId: 'sharepoint',
  ),
  SuggestionTemplate(
    id: 'shopify-0',
    blockType: 'shopify',
    label: 'Shopify order monitor',
    prompt:
        'Build a workflow that monitors Shopify orders, flags high-value or unusual orders for review, tracks fulfillment status in a table, and sends daily inventory and sales summaries to Slack with restock alerts when items run low.',
    iconId: 'brand/shopify-icon',
    modules: <String>['tables', 'scheduled', 'agent', 'workflows'],
    providerId: 'shopify',
  ),
  SuggestionTemplate(
    id: 'shopify-1',
    blockType: 'shopify',
    label: 'Shopify unpaid order recovery',
    prompt:
        'Build a scheduled workflow that lists Shopify orders left open and unpaid in the past day, drafts a personalized recovery email referencing the items, and sends it via Gmail while logging recovery attempts to a table.',
    iconId: 'brand/shopify-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'shopify',
  ),
  SuggestionTemplate(
    id: 'shopify-2',
    blockType: 'shopify',
    label: 'Shopify restock alerter',
    prompt:
        'Create a scheduled hourly workflow that lists Shopify inventory items, computes days-of-cover from recent sales velocity, flags SKUs below a configurable threshold, and posts a Slack alert to the operations channel with the variant, location, and recommended reorder quantity.',
    iconId: 'brand/shopify-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'shopify',
  ),
  SuggestionTemplate(
    id: 'shopify-3',
    blockType: 'shopify',
    label: 'Shopify VIP segmenter',
    prompt:
        'Build a scheduled weekly workflow that pulls Shopify customers, uses amount spent and lifetime order count to group them into VIP and regular cohorts in a tracking table, and emails the marketing team via Gmail with a list of new VIPs to nurture.',
    iconId: 'brand/shopify-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'shopify',
  ),
  SuggestionTemplate(
    id: 'shopify-4',
    blockType: 'shopify',
    label: 'Shopify fulfillment tracker',
    prompt:
        'Create a scheduled workflow that lists Shopify orders and their fulfillment status, updates a status table with fulfillment status and tracking links, and proactively emails customers when their order misses an SLA so support gets ahead of the inquiry.',
    iconId: 'brand/shopify-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'shopify',
  ),
  SuggestionTemplate(
    id: 'shopify-5',
    blockType: 'shopify',
    label: 'Shopify product launcher',
    prompt:
        'Build a workflow that takes a new product brief, creates a draft product in Shopify, creates its variants with pricing, adds it to a collection using Collections To Join, drafts a launch announcement, and sends a Slack and Gmail draft announcement for marketing review. Publish to sales channels in Shopify after approval.',
    iconId: 'brand/shopify-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'shopify',
  ),
  SuggestionTemplate(
    id: 'shopify-6',
    blockType: 'shopify',
    label: 'Shopify order anomaly detector',
    prompt:
        'Create a scheduled workflow that runs every fifteen minutes, lists recent Shopify orders, scores each for anomalies — high value, unusual destination, mismatched billing — flags suspects in a review queue table, and Slacks the operations team for hands-on inspection.',
    iconId: 'brand/shopify-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'shopify',
  ),
  SuggestionTemplate(
    id: 'similarweb-0',
    blockType: 'similarweb',
    label: 'Similarweb traffic intelligence',
    prompt:
        'Build a scheduled workflow that pulls Similarweb traffic data for tracked competitor domains monthly, writes traffic, sources, and engagement to a tables-based scoreboard, and flags step changes in Slack.',
    iconId: 'brand/similarweb-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'similarweb-1',
    blockType: 'similarweb',
    label: 'Similarweb account intel sync',
    prompt:
        'Create a workflow that watches my CRM for new accounts, pulls Similarweb data on each account domain, writes traffic estimates, rankings, and engagement signals back to the account record for sales context.',
    iconId: 'brand/similarweb-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'similarweb-2',
    blockType: 'similarweb',
    label: 'Similarweb category benchmarking',
    prompt:
        'Create a scheduled workflow that pulls Similarweb category rank, visit duration, and bounce rate for my domain and a set of tracked competitors, then writes a ranked benchmarking table for the marketing review.',
    iconId: 'brand/similarweb-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'similarweb-3',
    blockType: 'similarweb',
    label: 'Similarweb funnel-source analyzer',
    prompt:
        'Build a scheduled workflow that pulls Similarweb traffic-source data for my domain and competitors, surfaces shifting acquisition channels, and writes the analysis to a marketing table.',
    iconId: 'brand/similarweb-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'similarweb-4',
    blockType: 'similarweb',
    label: 'Similarweb traffic-source overlap finder',
    prompt:
        'Create a scheduled workflow that pulls Similarweb traffic-source breakdowns for my domain and tracked competitors, identifies channels where competitors over-index, and writes an acquisition opportunity table.',
    iconId: 'brand/similarweb-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'similarweb-5',
    blockType: 'similarweb',
    label: 'Similarweb engagement scorecard',
    prompt:
        'Build a scheduled workflow that pulls Similarweb bounce rate, pages per visit, and average visit duration for my domain and key competitors, writes the engagement metrics to a table, and posts a Slack scorecard highlighting where my site under- or over-performs the set.',
    iconId: 'brand/similarweb-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'similarweb-6',
    blockType: 'similarweb',
    label: 'Similarweb prospect prioritizer',
    prompt:
        'Create a workflow that reads a list of target company domains from a table, pulls each domain\'s Similarweb website overview and monthly visits, scores them by traffic size and growth, and writes a prioritized outbound list for the sales team.',
    iconId: 'brand/similarweb-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sixtyfour-0',
    blockType: 'sixtyfour',
    label: 'Sixtyfour contact researcher',
    prompt:
        'Build a workflow that runs Sixtyfour AI on inbound leads, enriches with deep research-grade signals, and writes a research brief into the CRM contact record.',
    iconId: 'brand/sixtyfour-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sixtyfour-1',
    blockType: 'sixtyfour',
    label: 'Sixtyfour account intelligence',
    prompt:
        'Create a workflow that for tracked accounts runs Sixtyfour deep research weekly, surfaces new signals, and writes the digest into a research table.',
    iconId: 'brand/sixtyfour-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sixtyfour-2',
    blockType: 'sixtyfour',
    label: 'Sixtyfour outbound briefer',
    prompt:
        'Build a workflow that runs Sixtyfour on a prospect, generates a tailored outreach brief with hooks, and queues it for the rep to send via Email Bison.',
    iconId: 'brand/sixtyfour-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sixtyfour-3',
    blockType: 'sixtyfour',
    label: 'Sixtyfour event-attendee researcher',
    prompt:
        'Create a workflow that takes a Luma event attendee list, runs Sixtyfour deep research per attendee, and writes per-person briefs for the sales team.',
    iconId: 'brand/sixtyfour-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sixtyfour-4',
    blockType: 'sixtyfour',
    label: 'Sixtyfour competitor-intel digest',
    prompt:
        'Build a scheduled weekly workflow that runs Sixtyfour deep research on competitors and writes a competitive-intel digest to a Slack channel.',
    iconId: 'brand/sixtyfour-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sixtyfour-5',
    blockType: 'sixtyfour',
    label: 'Sixtyfour CRM enricher',
    prompt:
        'Create a scheduled workflow that finds CRM accounts missing deep-research signals, runs Sixtyfour, and writes the structured findings back to the account record.',
    iconId: 'brand/sixtyfour-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sixtyfour-6',
    blockType: 'sixtyfour',
    label: 'Sixtyfour deal-prep packet',
    prompt:
        'Build a workflow that runs Sixtyfour the morning of every meeting, generates a meeting-prep packet with company and attendee research, and emails the rep.',
    iconId: 'brand/sixtyfour-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'slack-0',
    blockType: 'slack',
    label: 'Slack Q&A bot',
    prompt:
        'Create a knowledge base connected to my Notion workspace so it stays synced with my company wiki. Then build a workflow that monitors Slack channels for questions and answers them using the knowledge base with source citations.',
    iconId: 'brand/slack-icon',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
    providerId: 'slack',
  ),
  SuggestionTemplate(
    id: 'slack-1',
    blockType: 'slack',
    label: 'Slack churn risk alerts',
    prompt:
        'Create a workflow that monitors customer activity — support ticket frequency, response sentiment, usage patterns — scores each account for churn risk in a table, and triggers a Slack alert to the account team when a customer crosses the risk threshold.',
    iconId: 'emcn/table',
    modules: <String>['tables', 'scheduled', 'agent', 'workflows'],
    providerId: 'slack',
  ),
  SuggestionTemplate(
    id: 'slack-2',
    blockType: 'slack',
    label: 'Slack incident postmortem writer',
    prompt:
        'Create a workflow that when triggered after an incident, pulls the Slack thread from the incident channel, gathers relevant Sentry errors and deployment logs, and drafts a structured postmortem with timeline, root cause, and action items.',
    iconId: 'brand/slack-icon',
    modules: <String>['agent', 'files', 'workflows'],
    providerId: 'slack',
  ),
  SuggestionTemplate(
    id: 'slack-3',
    blockType: 'slack',
    label: 'Slack code Q&A bot',
    prompt:
        'Build a workflow that monitors a Slack channel for code questions, routes them to Greptile against the relevant repository, and replies in-thread with the answer and the cited files so the team gets quick, sourced engineering answers.',
    iconId: 'brand/greptile-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'slack',
  ),
  SuggestionTemplate(
    id: 'slack-4',
    blockType: 'slack',
    label: 'Slack knowledge search',
    prompt:
        'Create a knowledge base connected to my Slack workspace so all channel conversations and threads are automatically synced and searchable. Then build an agent I can ask things like "what did the team decide about the launch date?" or "what was the outcome of the design review?" and get answers with links to the original messages.',
    iconId: 'brand/slack-icon',
    modules: <String>['knowledge-base', 'agent'],
    providerId: 'slack',
  ),
  SuggestionTemplate(
    id: 'slack-5',
    blockType: 'slack',
    label: 'Slack narrative report',
    prompt:
        'Build a scheduled workflow that pulls key data from my tables every week, analyzes trends and anomalies, and writes a narrative report — not just charts and numbers, but written insights explaining what changed, why it matters, and what to do next. Save it as a document and send a summary to Slack.',
    iconId: 'emcn/file',
    modules: <String>['tables', 'scheduled', 'agent', 'files', 'workflows'],
    providerId: 'slack',
  ),
  SuggestionTemplate(
    id: 'slack-6',
    blockType: 'slack',
    label: 'Slack reading digest',
    prompt:
        'Create a scheduled daily workflow that searches the web for the latest articles, papers, and news on topics I care about, picks the top 5 most relevant pieces, writes a one-paragraph summary for each, and delivers a curated reading digest to my inbox or Slack.',
    iconId: 'emcn/book-open',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
    providerId: 'slack',
  ),
  SuggestionTemplate(
    id: 'slack-7',
    blockType: 'slack',
    label: 'Slack standup summary',
    prompt:
        'Create a scheduled workflow that reads the #standup Slack channel each morning, summarizes what everyone is working on, identifies blockers, and posts a structured recap to a Google Docs document.',
    iconId: 'emcn/clipboard-list',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
    providerId: 'slack',
  ),
  SuggestionTemplate(
    id: 'slack-8',
    blockType: 'slack',
    label: 'Slack onboarding automation',
    prompt:
        'Build a workflow that when triggered with a new hire\'s info, creates their accounts, sends a personalized welcome message in Slack, schedules 1:1s with their team on Google Calendar, shares relevant onboarding docs from the knowledge base, and tracks completion in a table.',
    iconId: 'emcn/users',
    modules: <String>['knowledge-base', 'tables', 'agent', 'workflows'],
    providerId: 'slack',
  ),
  SuggestionTemplate(
    id: 'slack-9',
    blockType: 'slack',
    label: 'Slack customer 360 alerts',
    prompt:
        'Create a comprehensive customer table that aggregates data from my CRM, support tickets, billing history, and product usage into a single unified view per customer. Schedule it to sync daily and send a Slack alert when any customer shows signs of trouble across multiple signals.',
    iconId: 'emcn/table',
    modules: <String>['tables', 'scheduled', 'agent', 'workflows'],
    providerId: 'slack',
  ),
  SuggestionTemplate(
    id: 'slack-10',
    blockType: 'slack',
    label: 'Slack thread translator',
    prompt:
        'Build a workflow that watches international Slack channels, detects non-English messages, translates them with Google Translate, and posts the English version in a thread so the wider team stays in the loop.',
    iconId: 'brand/google-translate-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'slack',
  ),
  SuggestionTemplate(
    id: 'slack-11',
    blockType: 'slack',
    label: 'Archive Slack conversations to Notion',
    prompt:
        'Build a workflow that captures important Slack messages and threads and saves them as Notion pages or database entries, so meeting notes and decisions are always documented.',
    iconId: 'brand/slack-icon',
    modules: <String>['agent', 'workflows'],
    featured: true,
    providerId: 'slack',
  ),
  SuggestionTemplate(
    id: 'smartlead-0',
    blockType: 'smartlead',
    label: 'Smartlead campaign builder',
    prompt:
        'Build a workflow that takes a target persona and offer, drafts a three-step Smartlead email sequence with {{first_name}} and {{company_name}} personalization, creates the campaign, saves the sequence, sets a weekday 9-to-5 sending schedule, and reports the campaign ID for review before it is started.',
    iconId: 'brand/smartlead-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'smartlead-1',
    blockType: 'smartlead',
    label: 'Smartlead reply triage',
    prompt:
        'Create a scheduled workflow that pulls Smartlead campaign statistics filtered to replied, reads each lead message history, classifies the reply as interested, not interested, objection, or out-of-office, sets the matching Smartlead lead category, and posts hot replies to a Slack channel.',
    iconId: 'brand/smartlead-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'smartlead-2',
    blockType: 'smartlead',
    label: 'Smartlead lead loader',
    prompt:
        'Build a workflow that reads prospects from a table, normalizes each name, company, and email, adds them to a Smartlead campaign in batches of 400 with the block list respected, and writes back how many were uploaded versus skipped as duplicates, bounces, or invalid emails.',
    iconId: 'brand/smartlead-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'smartlead-3',
    blockType: 'smartlead',
    label: 'Smartlead weekly outbound digest',
    prompt:
        'Create a scheduled weekly workflow that lists Smartlead campaigns, pulls analytics by date for the last seven days for each active campaign, computes open, click, and reply rates, ranks best and worst performers, and emails the digest to the sales lead.',
    iconId: 'brand/smartlead-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'smartlead-4',
    blockType: 'smartlead',
    label: 'Smartlead + HubSpot sync',
    prompt:
        'Build a workflow that reads Smartlead campaign leads and their categories, finds or creates the matching HubSpot contact, mirrors the outreach status onto the contact, and creates a HubSpot task for a rep whenever a lead is categorized as interested.',
    iconId: 'brand/smartlead-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'smartlead-5',
    blockType: 'smartlead',
    label: 'Smartlead bounce cleanup',
    prompt:
        'Create a scheduled workflow that pulls Smartlead campaign statistics filtered to bounced, pauses each bounced lead, records the suppression in a table with the campaign and bounce date, and reports how many leads were paused so deliverability stays healthy.',
    iconId: 'brand/smartlead-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'smartlead-6',
    blockType: 'smartlead',
    label: 'Smartlead sequence A/B rewriter',
    prompt:
        'Build a workflow that reads a Smartlead campaign sequence and its per-step statistics, identifies the step with the weakest reply rate, drafts two stronger subject and body variants for it, and saves the updated sequence back to the campaign after a human approves.',
    iconId: 'brand/smartlead-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'smartlead-7',
    blockType: 'smartlead',
    label: 'Smartlead engagement webhook wiring',
    prompt:
        'Create a workflow that lists Smartlead campaigns, checks which ones are missing a reply webhook, and registers a webhook on each for EMAIL_REPLY and LEAD_UNSUBSCRIBED scoped to the Interested category so downstream automations receive engagement events.',
    iconId: 'brand/smartlead-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'smtp-0',
    blockType: 'smtp',
    label: 'SMTP daily digest email',
    prompt:
        'Build a scheduled workflow that gathers the day’s key updates, has an agent write a clean HTML summary, and sends it as a daily digest email to the team over SMTP.',
    iconId: 'brand/smtp-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'smtp-1',
    blockType: 'smtp',
    label: 'SMTP alert email on threshold',
    prompt:
        'Create a workflow that checks a metric or status, and when it crosses a threshold, sends an alert email over SMTP with the details and a clear subject so the on-call person notices immediately.',
    iconId: 'brand/smtp-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'smtp-2',
    blockType: 'smtp',
    label: 'SMTP report as attachment',
    prompt:
        'Build a workflow that generates a report file, then sends it as an email attachment over SMTP to the requested recipients with a short summary in the body.',
    iconId: 'brand/smtp-icon',
    modules: <String>['files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'smtp-3',
    blockType: 'smtp',
    label: 'SMTP outreach from a table',
    prompt:
        'Create a workflow that reads a table of recipients, has an agent draft a personalized message for each row, and sends an individual email to every contact over SMTP with their name and details filled in.',
    iconId: 'brand/smtp-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'smtp-4',
    blockType: 'smtp',
    label: 'SMTP form-submission auto-reply',
    prompt:
        'Build a workflow that triggers on a new form submission and sends an automatic confirmation email over SMTP to the submitter, using their address as the recipient and a friendly reply-to.',
    iconId: 'brand/smtp-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'smtp-5',
    blockType: 'smtp',
    label: 'SMTP incident notification',
    prompt:
        'Create a workflow that, when an incident is detected, sends a notification email over SMTP to a distribution list with the severity, impact, and next steps, cc’ing the stakeholders who need to be looped in.',
    iconId: 'brand/smtp-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'smtp-6',
    blockType: 'smtp',
    label: 'SMTP weekly summary email',
    prompt:
        'Build a scheduled workflow that compiles the week’s results into an HTML summary with an agent and emails it over SMTP to the team every Friday, with a link-friendly reply-to for follow-ups.',
    iconId: 'brand/smtp-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'snowflake-0',
    blockType: 'snowflake',
    label: 'Snowflake asynchronous reporting',
    prompt:
        'Build a scheduled workflow that starts a long-running Snowflake report asynchronously, polls its statement handle until complete, summarizes the result, and posts the report to Slack.',
    iconId: 'brand/snowflake-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'snowflake-1',
    blockType: 'snowflake',
    label: 'Snowflake incremental upsert',
    prompt:
        'Create a workflow that receives changed customer records, validates their keys, and upserts them into a Snowflake dimension table in bounded batches.',
    iconId: 'brand/snowflake-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'snowflake-2',
    blockType: 'snowflake',
    label: 'Snowflake staged ingestion',
    prompt:
        'Build a workflow that loads newly staged CSV files into a Snowflake table with a named file format, records COPY results, and alerts on rejected files.',
    iconId: 'brand/snowflake-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'snowflake-3',
    blockType: 'snowflake',
    label: 'Snowflake task failure monitor',
    prompt:
        'Create a workflow that checks recent Snowflake task failures, retrieves the failed run details, summarizes the likely cause, and posts an actionable Slack alert.',
    iconId: 'brand/snowflake-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'snowflake-4',
    blockType: 'snowflake',
    label: 'Snowflake warehouse cost control',
    prompt:
        'Build a scheduled workflow that reviews Snowflake warehouse state and suspends an approved idle warehouse after notifying the data platform channel.',
    iconId: 'brand/snowflake-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'snowflake-5',
    blockType: 'snowflake',
    label: 'Snowflake result export',
    prompt:
        'Build a scheduled workflow that unloads a Snowflake query result to a stage as a single CSV file with headers, then posts the file count and row total to Slack.',
    iconId: 'brand/snowflake-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'snowflake-6',
    blockType: 'snowflake',
    label: 'Snowflake ingestion audit',
    prompt:
        'Create a workflow that reviews Snowflake copy history for a landing table, identifies files that failed to load, and opens a ticket with the first error on each one.',
    iconId: 'brand/snowflake-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'snowflake-7',
    blockType: 'snowflake',
    label: 'Snowflake slow-query review',
    prompt:
        'Build a weekly workflow that lists the longest-running Snowflake queries on a warehouse, summarizes the patterns behind them, and reports the top offenders with their elapsed times.',
    iconId: 'brand/snowflake-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'snowflake-8',
    blockType: 'snowflake',
    label: 'Snowflake task pause and resume',
    prompt:
        'Create a workflow that suspends a Snowflake task when its recent runs keep failing, notifies the data platform channel, and resumes it once someone confirms the fix.',
    iconId: 'brand/snowflake-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'snowflake-9',
    blockType: 'snowflake',
    label: 'Snowflake schema-drift audit',
    prompt:
        'Create a daily workflow that introspects a Snowflake schema, compares its tables and columns with the previous snapshot, and reports breaking schema changes.',
    iconId: 'brand/snowflake-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'snowflake-10',
    blockType: 'snowflake',
    label: 'Snowflake procedure orchestrator',
    prompt:
        'Build a workflow that validates typed arguments, calls a Snowflake stored procedure, captures its output, and routes failures for operator review.',
    iconId: 'brand/snowflake-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'snowflake-11',
    blockType: 'snowflake',
    label: 'Snowflake Cortex Analyst Slack analyst',
    prompt:
        'Build an agent that answers data questions asked in a Slack channel with Snowflake Cortex Analyst over our semantic view. It keeps each Slack thread\'s Cortex Analyst conversation in a table so follow-up questions keep their context, starting fresh after a handful of turns, runs the generated SQL, and replies in the thread with the interpretation, a short table of rows, and the SQL.',
    iconId: 'brand/snowflake-icon',
    modules: <String>['agent', 'tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'snowflake-12',
    blockType: 'snowflake',
    label: 'Snowflake Cortex Analyst router',
    prompt:
        'Create an agent that sends each incoming business question to Snowflake Cortex Analyst with our sales, finance, and support semantic views, lets Cortex Analyst pick the right one, runs the generated SQL, and posts the results and which view answered to Slack, or posts the suggested rephrasings when the question is ambiguous.',
    iconId: 'brand/snowflake-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'snowflake-13',
    blockType: 'snowflake',
    label: 'Snowflake Cortex Analyst KPI digest',
    prompt:
        'Build a scheduled workflow that asks Snowflake Cortex Analyst a fixed list of weekly KPI questions against our semantic view, runs each generated SQL, and posts a digest of the results and the SQL behind them to a Slack channel every Monday.',
    iconId: 'brand/snowflake-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'splunk-0',
    blockType: 'splunk',
    label: 'Splunk error spike triage',
    prompt:
        'Build a scheduled workflow that runs a Splunk SPL search for error spikes every 15 minutes, summarizes the top offending hosts and sourcetypes with an agent, and posts the triage summary to Slack.',
    iconId: 'brand/splunk-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'splunk-1',
    blockType: 'splunk',
    label: 'Splunk alert to incident',
    prompt:
        'Create a scheduled workflow that polls Splunk fired alerts, deduplicates them by saved search, and opens a PagerDuty incident with the alert severity and the search ID attached.',
    iconId: 'brand/splunk-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'splunk-2',
    blockType: 'splunk',
    label: 'Splunk security digest',
    prompt:
        'Build a scheduled daily workflow that dispatches a Splunk saved search for failed authentication attempts, waits for the job to finish, and emails a security digest with the top source IPs.',
    iconId: 'brand/splunk-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'splunk-3',
    blockType: 'splunk',
    label: 'Splunk log export to tables',
    prompt:
        'Create a scheduled workflow that runs a Splunk search for the previous hour of transaction logs and writes the results into a Sim table for downstream reporting.',
    iconId: 'brand/splunk-icon',
    modules: <String>['scheduled', 'tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'splunk-4',
    blockType: 'splunk',
    label: 'Splunk index capacity watch',
    prompt:
        'Build a scheduled weekly workflow that lists Splunk indexes, flags any index close to its maximum data size or retention limit, and posts a capacity warning to the platform team in Slack.',
    iconId: 'brand/splunk-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'splunk-5',
    blockType: 'splunk',
    label: 'Splunk saved search inventory',
    prompt:
        'Create a scheduled monthly workflow that lists every Splunk saved search, flags scheduled searches that have not run recently or are disabled, and writes a cleanup queue to a Sim table.',
    iconId: 'brand/splunk-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'splunk-6',
    blockType: 'splunk',
    label: 'Splunk incident context agent',
    prompt:
        'Build an agent workflow that takes an incident description, runs targeted Splunk searches for the affected service, and returns a timeline of the relevant log events with the matching search ID.',
    iconId: 'brand/splunk-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'splunk-7',
    blockType: 'splunk',
    label: 'Splunk + Jira defect linking',
    prompt:
        'Create a scheduled workflow that runs a Splunk search for recurring application exceptions and opens or updates a Jira bug for each distinct stack trace with the event count attached.',
    iconId: 'brand/splunk-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sportmonks-0',
    blockType: 'sportmonks',
    label: 'Sportmonks daily fixtures digest',
    prompt:
        'Build a scheduled daily workflow that fetches today\'s football fixtures from Sportmonks for the leagues I follow, summarizes the key matchups and kickoff times, and posts the digest to Slack.',
    iconId: 'brand/sportmonks-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sportmonks-1',
    blockType: 'sportmonks',
    label: 'Sportmonks live score alerter',
    prompt:
        'Create a scheduled workflow that polls Sportmonks inplay football scores, detects goals and status changes since the last run, and pings Slack with the updated scoreline for tracked matches.',
    iconId: 'brand/sportmonks-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sportmonks-2',
    blockType: 'sportmonks',
    label: 'Sportmonks league standings report',
    prompt:
        'Build a scheduled weekly workflow that pulls the Sportmonks football standings and topscorers for a season, formats a league table with recent form, and emails the report to the group.',
    iconId: 'brand/sportmonks-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sportmonks-3',
    blockType: 'sportmonks',
    label: 'Sportmonks race weekend digest',
    prompt:
        'Build a scheduled workflow that fetches this weekend\'s motorsport sessions from Sportmonks, summarizes the practice, qualifying, and race times, and posts the schedule to Slack.',
    iconId: 'brand/sportmonks-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sportmonks-4',
    blockType: 'sportmonks',
    label: 'Sportmonks championship tracker',
    prompt:
        'Create a scheduled weekly workflow that pulls the Sportmonks motorsport driver and constructor standings for the current season, formats the championship tables, and emails them to the group.',
    iconId: 'brand/sportmonks-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sportmonks-5',
    blockType: 'sportmonks',
    label: 'Sportmonks pre-match odds snapshot',
    prompt:
        'Build a workflow that pulls Sportmonks pre-match odds for a fixture across selected bookmakers, computes the implied probability for each outcome, and writes the snapshot to a table.',
    iconId: 'brand/sportmonks-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sportmonks-6',
    blockType: 'sportmonks',
    label: 'Sportmonks live odds alerter',
    prompt:
        'Create a scheduled workflow that polls Sportmonks in-play odds for a fixture, detects sharp price moves since the last run, and pings Slack with the updated lines.',
    iconId: 'brand/sportmonks-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sportmonks-7',
    blockType: 'sportmonks',
    label: 'Sportmonks head-to-head preview',
    prompt:
        'Create a workflow that takes two team names, resolves them to IDs via Sportmonks football team search, pulls their head-to-head history and current standings, and writes a match preview file.',
    iconId: 'brand/sportmonks-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sqs-0',
    blockType: 'sqs',
    label: 'SQS event dispatcher',
    prompt:
        'Build a workflow that runs after a customer event is processed, formats a structured message, and pushes it onto an Amazon SQS queue so downstream worker services can pick it up. Log every dispatched event into a table for audit and replay.',
    iconId: 'brand/sqs-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sqs-1',
    blockType: 'sqs',
    label: 'SQS dead-letter replayer',
    prompt:
        'Create a scheduled workflow that runs every morning, scans a table of failed jobs, regenerates the original payload, and republishes each failed message to its Amazon SQS queue with retry metadata so transient failures are recovered automatically.',
    iconId: 'brand/sqs-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sqs-2',
    blockType: 'sqs',
    label: 'Webhook to SQS bridge',
    prompt:
        'Build a workflow exposed as a webhook endpoint that accepts inbound events from third-party services, validates the payload against a schema, transforms it into your internal event format, sends it to Amazon SQS for asynchronous processing, and returns an acknowledgement to the caller.',
    iconId: 'brand/sqs-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sqs-3',
    blockType: 'sqs',
    label: 'SQS alert enricher',
    prompt:
        'Create a workflow triggered by PagerDuty or Datadog alerts that classifies severity, decorates the payload with runbook context, and pushes the enriched alert to an Amazon SQS queue so multiple downstream notifiers and ticketing systems can consume it independently.',
    iconId: 'brand/sqs-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sqs-4',
    blockType: 'sqs',
    label: 'SQS batch order queue',
    prompt:
        'Build a workflow that takes a list of orders from a table and queues each one as a separate Amazon SQS message for parallel downstream processing. Track each enqueued message ID in the table so you can correlate downstream results back to the originating row.',
    iconId: 'brand/sqs-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sqs-5',
    blockType: 'sqs',
    label: 'Scheduled SQS fan-out',
    prompt:
        'Create a scheduled workflow that runs every fifteen minutes, queries pending items from a table, batches them, and pushes one Amazon SQS message per batch to your worker queue. Update the table with batch IDs and timestamps so reprocessing is deterministic.',
    iconId: 'brand/sqs-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sqs-6',
    blockType: 'sqs',
    label: 'SQS cross-service notifier',
    prompt:
        'Build a workflow that listens for completed builds in your CI tool, composes a status payload with build metadata and artifact links, and sends the payload to an Amazon SQS queue so internal services like deploy, audit, and notification workers can react asynchronously.',
    iconId: 'brand/sqs-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'square-0',
    blockType: 'square',
    label: 'Square daily sales summary',
    prompt:
        'Build a scheduled daily workflow that lists Square payments from the previous day across all locations, totals gross sales, refunds, and net revenue, writes the figures to a table for historical tracking, and posts a Slack summary with day-over-day trends.',
    iconId: 'brand/square-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'square-1',
    blockType: 'square',
    label: 'Square refund pattern monitor',
    prompt:
        'Create a scheduled weekly workflow that lists Square payments and their refunds, classifies each refund by reason and location, flags any location with an unusually high refund rate, and emails finance a narrative report with recommended actions.',
    iconId: 'brand/square-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'square-2',
    blockType: 'square',
    label: 'Square new customer welcome',
    prompt:
        'Build a workflow that takes a new Square customer, creates a welcome email tailored to their purchase, adds them to an onboarding tracking table, and posts a notification to the customer success Slack channel.',
    iconId: 'brand/square-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'square-3',
    blockType: 'square',
    label: 'Square invoice chase automation',
    prompt:
        'Create a scheduled workflow that lists Square invoices for a location, finds those that are unpaid past their due date, sends a polite reminder email per customer, and logs every chase action to a collections table.',
    iconId: 'brand/square-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'square-4',
    blockType: 'square',
    label: 'Square catalog image enrichment',
    prompt:
        'Build a workflow that lists Square catalog items missing images, generates a product image for each one, uploads it as a catalog image attached to the item, and writes a report of which items were updated.',
    iconId: 'brand/square-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'square-5',
    blockType: 'square',
    label: 'Square low-stock reorder alerts',
    prompt:
        'Create a scheduled workflow that lists the Square catalog, identifies items flagged as low or out of stock, drafts a reorder summary grouped by supplier, and posts it to a Slack purchasing channel with the items and quantities to reorder.',
    iconId: 'brand/square-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'square-6',
    blockType: 'square',
    label: 'Square purchase history lookup',
    prompt:
        'Build a workflow that searches Square customers by email, pulls their orders and payments, summarizes lifetime spend and most-purchased items, and returns a concise profile the support team can use during a conversation.',
    iconId: 'brand/square-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ssh-0',
    blockType: 'ssh',
    label: 'SSH health check to Slack',
    prompt:
        'Every morning, SSH into the production server and run a health check command (uptime, load average, and free memory). Summarize stdout with an agent and post the result to the #ops Slack channel so the team starts the day knowing the box is healthy.',
    iconId: 'brand/ssh-terminal-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ssh-1',
    blockType: 'ssh',
    label: 'Disk-usage alert with SSH',
    prompt:
        'On a schedule, SSH into the server and execute \'df -h /\' to read disk usage. Parse the stdout, and if the used percentage crosses 85%, send an alert to Slack with the current usage; otherwise stay silent.',
    iconId: 'emcn/server',
    modules: <String>['scheduled', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ssh-2',
    blockType: 'ssh',
    label: 'Run a deploy script over SSH',
    prompt:
        'Trigger a deployment by SSHing into the app server and executing a maintenance script that pulls the latest code, installs dependencies, rebuilds, and restarts the service. Check the exitCode and success outputs, then report stdout and stderr back so failures are visible.',
    iconId: 'emcn/wrench',
    modules: <String>['workflows', 'agent'],
  ),
  SuggestionTemplate(
    id: 'ssh-3',
    blockType: 'ssh',
    label: 'Summarize a remote log over SSH',
    prompt:
        'SSH into the server and read the last 200 lines of /var/log/app.log, then hand the content to an agent that summarizes recent errors and warnings into a short digest. Post the digest so on-call engineers can scan incidents at a glance.',
    iconId: 'emcn/clipboard-list',
    modules: <String>['workflows', 'agent'],
  ),
  SuggestionTemplate(
    id: 'ssh-4',
    blockType: 'ssh',
    label: 'Fetch a remote report over SSH',
    prompt:
        'Download a generated report file from the remote server via SSH and pass the resulting file output into the next step for processing or storage, so a nightly export on the box flows straight into the workflow.',
    iconId: 'emcn/download',
    modules: <String>['scheduled', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ssh-5',
    blockType: 'ssh',
    label: 'Verify a command exists over SSH',
    prompt:
        'Before executing a maintenance step, use Check Command Exists over SSH to confirm a tool like docker or git is installed on the remote host. If the exists output is true, run the command; if not, report a clear message that the dependency is missing.',
    iconId: 'emcn/search',
    modules: <String>['workflows'],
  ),
  SuggestionTemplate(
    id: 'ssh-6',
    blockType: 'ssh',
    label: 'Push a config and restart over SSH',
    prompt:
        'Upload a rendered configuration file to the remote server via SSH, write it to the target path, then execute a command to restart the affected service. Confirm success from the exitCode and stderr outputs before finishing.',
    iconId: 'emcn/file',
    modules: <String>['workflows', 'agent'],
  ),
  SuggestionTemplate(
    id: 'ssh_v2-0',
    blockType: 'ssh_v2',
    label: 'SSH health check to Slack',
    prompt:
        'Every morning, SSH into the production server and run a health check command (uptime, load average, and free memory). Summarize stdout with an agent and post the result to the #ops Slack channel so the team starts the day knowing the box is healthy.',
    iconId: 'brand/ssh-terminal-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ssh_v2-1',
    blockType: 'ssh_v2',
    label: 'Disk-usage alert with SSH',
    prompt:
        'On a schedule, SSH into the server and execute \'df -h /\' to read disk usage. Parse the stdout, and if the used percentage crosses 85%, send an alert to Slack with the current usage; otherwise stay silent.',
    iconId: 'emcn/server',
    modules: <String>['scheduled', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ssh_v2-2',
    blockType: 'ssh_v2',
    label: 'Run a deploy script over SSH',
    prompt:
        'Trigger a deployment by SSHing into the app server and executing a maintenance script that pulls the latest code, installs dependencies, rebuilds, and restarts the service. Check the exitCode and success outputs, then report stdout and stderr back so failures are visible.',
    iconId: 'emcn/wrench',
    modules: <String>['workflows', 'agent'],
  ),
  SuggestionTemplate(
    id: 'ssh_v2-3',
    blockType: 'ssh_v2',
    label: 'Summarize a remote log over SSH',
    prompt:
        'SSH into the server and read the last 200 lines of /var/log/app.log, then hand the content to an agent that summarizes recent errors and warnings into a short digest. Post the digest so on-call engineers can scan incidents at a glance.',
    iconId: 'emcn/clipboard-list',
    modules: <String>['workflows', 'agent'],
  ),
  SuggestionTemplate(
    id: 'ssh_v2-4',
    blockType: 'ssh_v2',
    label: 'Fetch a remote report over SSH',
    prompt:
        'Download a generated report file from the remote server via SSH and pass the resulting file output into the next step for processing or storage, so a nightly export on the box flows straight into the workflow.',
    iconId: 'emcn/download',
    modules: <String>['scheduled', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ssh_v2-5',
    blockType: 'ssh_v2',
    label: 'Verify a command exists over SSH',
    prompt:
        'Before executing a maintenance step, use Check Command Exists over SSH to confirm a tool like docker or git is installed on the remote host. If the exists output is true, run the command; if not, report a clear message that the dependency is missing.',
    iconId: 'emcn/search',
    modules: <String>['workflows'],
  ),
  SuggestionTemplate(
    id: 'ssh_v2-6',
    blockType: 'ssh_v2',
    label: 'Push a config and restart over SSH',
    prompt:
        'Upload a rendered configuration file to the remote server via SSH, write it to the target path, then execute a command to restart the affected service. Confirm success from the exitCode and stderr outputs before finishing.',
    iconId: 'emcn/file',
    modules: <String>['workflows', 'agent'],
  ),
  SuggestionTemplate(
    id: 'ssm-0',
    blockType: 'ssm',
    label: 'Systems Manager patch reporter',
    prompt:
        'Build a scheduled workflow that reads AWS Systems Manager patch compliance for every managed node, flags nodes with missing critical or security patches, and posts a ranked remediation list to Slack.',
    iconId: 'brand/ssm-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ssm-1',
    blockType: 'ssm',
    label: 'Systems Manager agent health watch',
    prompt:
        'Create a scheduled workflow that lists AWS Systems Manager managed nodes, identifies nodes whose agent has lost connection or is running an outdated version, and opens a Jira ticket for each one.',
    iconId: 'brand/ssm-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ssm-2',
    blockType: 'ssm',
    label: 'Systems Manager runbook responder',
    prompt:
        'Build a workflow that receives an incident alert, starts the matching AWS Systems Manager Automation runbook, polls the execution until it finishes, and reports the step results back to the incident channel.',
    iconId: 'brand/ssm-icon',
    modules: <String>['agent', 'workflows'],
    featured: true,
  ),
  SuggestionTemplate(
    id: 'ssm-3',
    blockType: 'ssm',
    label: 'Systems Manager config promoter',
    prompt:
        'Create a workflow that reads application configuration from one AWS Systems Manager Parameter Store path, requests approval in Slack, writes the approved values to the production path, and records the change in a table.',
    iconId: 'brand/ssm-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ssm-4',
    blockType: 'ssm',
    label: 'Systems Manager fleet command runner',
    prompt:
        'Build a workflow that runs a diagnostic shell script on every AWS Systems Manager managed node carrying a chosen tag, collects the per-node output, and summarizes the failures for the on-call engineer.',
    iconId: 'brand/ssm-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ssm-5',
    blockType: 'ssm',
    label: 'Systems Manager compliance digest',
    prompt:
        'Create a scheduled workflow that pulls AWS Systems Manager compliance summaries, compares them with last week’s counts stored in a table, and emails leadership a short trend report.',
    iconId: 'brand/ssm-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ssm-6',
    blockType: 'ssm',
    label: 'Systems Manager parameter auditor',
    prompt:
        'Build a scheduled workflow that lists AWS Systems Manager Parameter Store metadata, flags SecureString parameters that have not changed within the rotation window and plaintext parameters that look like credentials, and files the findings for security review.',
    iconId: 'brand/ssm-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'ssm-7',
    blockType: 'ssm',
    label: 'Systems Manager runbook catalog',
    prompt:
        'Create a workflow that lists AWS Systems Manager Automation runbooks, reads the content of each one, and writes a plain-English catalog of what every runbook does and which parameters it needs.',
    iconId: 'brand/ssm-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'stagehand-0',
    blockType: 'stagehand',
    label: 'Stagehand QA navigator',
    prompt:
        'Build a workflow that uses Stagehand to run scripted browser flows against staging, captures screenshots and assertion outcomes per step, and writes a regression report file.',
    iconId: 'brand/stagehand-icon',
    modules: <String>['files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'stagehand-1',
    blockType: 'stagehand',
    label: 'Stagehand booking automator',
    prompt:
        'Create a workflow that uses Stagehand to log into supplier portals, place recurring orders from a tables-defined catalog, and write confirmation numbers back to the orders table.',
    iconId: 'brand/stagehand-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'stagehand-2',
    blockType: 'stagehand',
    label: 'Stagehand price-monitor sweep',
    prompt:
        'Build a scheduled workflow that uses Stagehand to navigate a catalog of supplier sites, capture current prices and stock for items in a tracking table, and alert Slack on threshold breaches.',
    iconId: 'brand/stagehand-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'stagehand-3',
    blockType: 'stagehand',
    label: 'Stagehand competitor product trial',
    prompt:
        'Build a workflow that uses Stagehand to walk through competitor product trials weekly, captures screenshots of every step, and writes a UX-comparison file.',
    iconId: 'brand/stagehand-icon',
    modules: <String>['scheduled', 'files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'stagehand-4',
    blockType: 'stagehand',
    label: 'Stagehand onboarding-flow auditor',
    prompt:
        'Create a workflow that uses Stagehand to test the production onboarding flow daily, captures friction points, and writes a UX regression table.',
    iconId: 'brand/stagehand-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'stagehand-5',
    blockType: 'stagehand',
    label: 'Stagehand structured lead extractor',
    prompt:
        'Build a workflow that uses Stagehand to visit a list of company sites from a table, extracts structured fields — company name, contact email, pricing tier, and key features — into a defined schema, and writes the clean records back into a research table for the sales team.',
    iconId: 'brand/stagehand-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'stagehand-6',
    blockType: 'stagehand',
    label: 'Stagehand autonomous task runner',
    prompt:
        'Create a workflow that hands Stagehand a natural-language goal like "find the latest pricing on this vendor site and download the PDF", lets the Stagehand agent navigate and act on the page autonomously, and saves the captured result and screenshots to files.',
    iconId: 'brand/stagehand-icon',
    modules: <String>['files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'stripe-0',
    blockType: 'stripe',
    label: 'Stripe weekly metrics report',
    prompt:
        'Build a scheduled workflow that pulls data from Stripe and my database every Monday, calculates key metrics like MRR, churn, new subscriptions, and failed payments, writes results to Google Sheets, and sends the team a Slack summary with week-over-week trends.',
    iconId: 'brand/stripe-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'stripe-1',
    blockType: 'stripe',
    label: 'Stripe revenue dashboard',
    prompt:
        'Create a scheduled daily workflow that pulls payment data from Stripe, calculates MRR, net revenue, failed payments, and new subscriptions, logs everything to a table with historical tracking, and sends a daily Slack summary with trends and anomalies.',
    iconId: 'brand/stripe-icon',
    modules: <String>['tables', 'scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'stripe-2',
    blockType: 'stripe',
    label: 'Stripe failed payment recovery',
    prompt:
        'Build a workflow that listens for Stripe failed-payment events, looks up the customer, classifies the failure reason, drafts a tailored recovery email and a Slack alert to the success team, and logs the attempt in a tracking table so recovery rate can be measured.',
    iconId: 'brand/stripe-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'stripe-3',
    blockType: 'stripe',
    label: 'Stripe churn flagger',
    prompt:
        'Create a scheduled daily workflow that lists Stripe subscriptions canceled or scheduled for cancellation, enriches each customer with usage and support history, scores the churn risk, and logs the cohort to a table with recommended save plays for the success team.',
    iconId: 'brand/stripe-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'stripe-4',
    blockType: 'stripe',
    label: 'Stripe invoice chaser',
    prompt:
        'Build a scheduled workflow that lists Stripe invoices overdue by more than seven days, sends a polite chase email tailored to the customer history, escalates to a Slack alert at thirty days, and writes every action into a collections tracking table.',
    iconId: 'brand/stripe-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'stripe-5',
    blockType: 'stripe',
    label: 'Stripe customer welcome flow',
    prompt:
        'Create a workflow triggered when a new Stripe customer is created. Send a personalized welcome email, create their onboarding checklist in a table, schedule a follow-up meeting via Calendly, and post a Slack notification to the customer success channel.',
    iconId: 'brand/stripe-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'stripe-6',
    blockType: 'stripe',
    label: 'Stripe refund pattern analyzer',
    prompt:
        'Build a scheduled weekly workflow that lists Stripe charge and dispute events, classifies each refund or dispute by reason and product, identifies recurring patterns or fraud signals, writes a narrative report file, and Slacks finance with the top concerns and recommended actions.',
    iconId: 'brand/stripe-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sts-0',
    blockType: 'sts',
    label: 'AWS STS access key identifier',
    prompt:
        'Build a workflow that takes an AWS access key ID, uses AWS STS to look up the owning account and entity, flags keys that belong to unexpected accounts, and pings the security Slack channel.',
    iconId: 'brand/sts-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sts-1',
    blockType: 'sts',
    label: 'STS short-lived credential provisioner',
    prompt:
        'Create a workflow that on a request grants short-lived AWS STS credentials with the minimum required scope, captures the audit record, and revokes on completion.',
    iconId: 'brand/sts-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sts-2',
    blockType: 'sts',
    label: 'STS caller identity verifier',
    prompt:
        'Build a scheduled workflow that calls AWS STS get caller identity for each configured set of credentials, confirms the resolved account and ARN match the expected principal, and writes a verification report.',
    iconId: 'brand/sts-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sts-3',
    blockType: 'sts',
    label: 'STS session token rotator',
    prompt:
        'Create a scheduled daily workflow that mints fresh AWS STS session tokens for service accounts that need them, records each token expiration in a security log, and flags any token issuance that fails.',
    iconId: 'brand/sts-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sts-4',
    blockType: 'sts',
    label: 'STS just-in-time access grant',
    prompt:
        'Build a workflow that handles JIT-access requests, captures Slack-based approval, mints short-lived AWS STS credentials, and writes the access record.',
    iconId: 'brand/sts-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sts-5',
    blockType: 'sts',
    label: 'STS cross-account access grant',
    prompt:
        'Create a workflow that handles cross-account access requests, assumes the target AWS STS role with the supplied external ID, requires owner attestation in Slack, and writes the grant record to a compliance table.',
    iconId: 'brand/sts-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sts-6',
    blockType: 'sts',
    label: 'STS Identity-Center role broker',
    prompt:
        'Build a workflow that takes an Identity Center user request, assumes the matching AWS STS role to mint scoped short-lived credentials, writes the issuance to a session log, and alerts Slack when a request targets a privileged role.',
    iconId: 'brand/sts-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sts-7',
    blockType: 'sts',
    label: 'STS CI/CD OIDC credential broker',
    prompt:
        'Build a workflow that receives an OIDC token from a CI/CD pipeline (e.g. GitHub Actions), calls AWS STS assume role with web identity to mint short-lived deployment credentials, and writes the issuance to an audit log.',
    iconId: 'brand/sts-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'sts-8',
    blockType: 'sts',
    label: 'STS SAML SSO role broker',
    prompt:
        'Create a workflow that takes a SAML assertion from a corporate identity provider, calls AWS STS assume role with SAML to grant scoped temporary credentials, and logs the session details for compliance review.',
    iconId: 'brand/sts-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'supabase-0',
    blockType: 'supabase',
    label: 'Supabase customer record sync',
    prompt:
        'Build a workflow that listens for Stripe new-customer events and upserts a row into a Supabase customers table with the correct plan and metadata, then emails a welcome message.',
    iconId: 'brand/supabase-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'supabase-1',
    blockType: 'supabase',
    label: 'Supabase nightly export to S3',
    prompt:
        'Create a scheduled workflow that runs each night, exports key Supabase tables to compressed JSON in S3 with date partitions, and writes the manifest to an audit table.',
    iconId: 'brand/supabase-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'supabase-2',
    blockType: 'supabase',
    label: 'Supabase row-level audit log',
    prompt:
        'Build a scheduled workflow that polls Supabase sensitive tables for recently changed rows, captures the diff against the last snapshot into an audit log table, and pings Slack on unusual write patterns.',
    iconId: 'brand/supabase-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'supabase-3',
    blockType: 'supabase',
    label: 'Supabase high-priority row alerter',
    prompt:
        'Create a scheduled workflow that polls Supabase frequently for high-priority rows — new orders, fraud flags — and posts a Slack alert with context for each new row it finds.',
    iconId: 'brand/supabase-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'supabase-4',
    blockType: 'supabase',
    label: 'Supabase storage cleanup',
    prompt:
        'Build a scheduled workflow that finds Supabase storage objects older than the retention policy or unreferenced in the database, deletes them, and writes a cleanup report.',
    iconId: 'brand/supabase-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'supabase-5',
    blockType: 'supabase',
    label: 'Supabase analytics digest',
    prompt:
        'Create a scheduled daily workflow that queries Supabase for new signups, active users, and key feature usage, and posts a digest to Slack with week-over-week trend.',
    iconId: 'brand/supabase-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'supabase-6',
    blockType: 'supabase',
    label: 'Supabase + Algolia search sync',
    prompt:
        'Build a scheduled workflow that mirrors Supabase tables into an Algolia index, propagates new and changed rows on each run, and writes sync lag to a tables-based monitor.',
    iconId: 'brand/supabase-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tailscale-0',
    blockType: 'tailscale',
    label: 'Tailscale device inventory',
    prompt:
        'Build a scheduled workflow that pulls Tailscale device inventory daily, identifies stale or non-compliant nodes, and writes a security review table.',
    iconId: 'brand/tailscale-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tailscale-1',
    blockType: 'tailscale',
    label: 'Tailscale ACL drift detector',
    prompt:
        'Create a scheduled workflow that diffs Tailscale ACLs against the source of truth, alerts on drift to Slack, and, on approval, pushes the corrected policy back with Set ACL.',
    iconId: 'brand/tailscale-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tailscale-2',
    blockType: 'tailscale',
    label: 'Tailscale new-hire provisioner',
    prompt:
        'Build a workflow that on a Workday new-hire event creates a scoped Tailscale auth key for the engineer, sets the right device tags, and writes the access record.',
    iconId: 'brand/tailscale-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tailscale-3',
    blockType: 'tailscale',
    label: 'Tailscale offboarder',
    prompt:
        'Create a workflow that on a Workday termination deletes the departing engineer\'s Tailscale devices, revokes their auth keys, suspends their tailnet user account, and writes the security audit log.',
    iconId: 'brand/tailscale-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tailscale-4',
    blockType: 'tailscale',
    label: 'Tailscale unauthorized-tag watcher',
    prompt:
        'Build a scheduled workflow that polls Tailscale device tags and the ACL for unauthorized changes, posts a Slack alert to the security channel, and writes the audit.',
    iconId: 'brand/tailscale-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tailscale-5',
    blockType: 'tailscale',
    label: 'Tailscale key-expiry sweeper',
    prompt:
        'Create a scheduled workflow that lists Tailscale auth keys expiring in 14 days, notifies owners, and rotates keys past their grace period.',
    iconId: 'brand/tailscale-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tailscale-6',
    blockType: 'tailscale',
    label: 'Tailscale access audit',
    prompt:
        'Build a scheduled monthly workflow that produces a Tailscale access-review report — devices, tags, ACL effective access — for the security team.',
    iconId: 'brand/tailscale-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tavily-0',
    blockType: 'tavily',
    label: 'Tavily research-augmented agent',
    prompt:
        'Create an agent that grounds every answer in fresh Tavily web search results, returns answers with inline citations, and saves long-form research to a knowledge base for re-use.',
    iconId: 'brand/tavily-icon',
    modules: <String>['agent', 'knowledge-base', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tavily-1',
    blockType: 'tavily',
    label: 'Tavily competitive monitor',
    prompt:
        'Create a scheduled workflow that runs Tavily searches for competitor mentions weekly, scores each by relevance, logs the top hits to a tables-based competitive log, and posts highlights to Slack.',
    iconId: 'brand/tavily-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tavily-2',
    blockType: 'tavily',
    label: 'Tavily research-augmented chat',
    prompt:
        'Build a chat agent that grounds each answer in fresh Tavily web search results, returns inline citations, and saves long-form answers to a knowledge base for re-use.',
    iconId: 'brand/tavily-icon',
    modules: <String>['agent', 'knowledge-base', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tavily-3',
    blockType: 'tavily',
    label: 'Tavily news watcher',
    prompt:
        'Create a scheduled daily workflow that runs Tavily searches for topics I follow, summarizes the top hits with citations, and posts a digest to Slack.',
    iconId: 'brand/tavily-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tavily-4',
    blockType: 'tavily',
    label: 'Tavily account refresher',
    prompt:
        'Build a workflow that walks accounts in the CRM, runs Tavily research on each for new funding, hiring, or product launches, and writes the digest back to the account record.',
    iconId: 'brand/tavily-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tavily-5',
    blockType: 'tavily',
    label: 'Tavily competitor mention log',
    prompt:
        'Create a scheduled workflow that runs Tavily searches for competitor mentions weekly, scores each by relevance, and writes a competitive log to a table.',
    iconId: 'brand/tavily-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tavily-6',
    blockType: 'tavily',
    label: 'Tavily URL content extractor',
    prompt:
        'Build a workflow that reads a table of article URLs, uses Tavily extract to pull the clean main content from each page, summarizes the key points with an agent, and writes the summary back to the row.',
    iconId: 'brand/tavily-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'telegram-0',
    blockType: 'telegram',
    label: 'Telegram alert relay',
    prompt:
        'Build a workflow that listens for critical alerts from Sentry or PagerDuty and forwards a concise summary with severity, link, and the on-call person to a Telegram group.',
    iconId: 'brand/telegram-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'telegram-1',
    blockType: 'telegram',
    label: 'Telegram price-action notifier',
    prompt:
        'Create a scheduled workflow that watches tracked assets in a table for price thresholds and pushes a Telegram message with the trigger, price, and a link to the chart.',
    iconId: 'brand/telegram-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'telegram-2',
    blockType: 'telegram',
    label: 'Telegram support bot',
    prompt:
        'Build a Telegram bot that answers product questions using a knowledge base with citations, escalates to a human via Intercom when it cannot answer, and logs every conversation to a table.',
    iconId: 'brand/telegram-icon',
    modules: <String>['knowledge-base', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'telegram-3',
    blockType: 'telegram',
    label: 'Telegram daily standup poller',
    prompt:
        'Create a scheduled workflow that posts a daily standup prompt to a Telegram group, collects the replies, and writes a structured standup digest to a Google Doc.',
    iconId: 'brand/telegram-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'telegram-4',
    blockType: 'telegram',
    label: 'Telegram broadcast scheduler',
    prompt:
        'Build a workflow that reads a tables-based content calendar and posts scheduled Telegram channel messages with formatted text, images, and links at the right time.',
    iconId: 'brand/telegram-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'telegram-5',
    blockType: 'telegram',
    label: 'Telegram form-reply collector',
    prompt:
        'Create a workflow that asks structured questions in Telegram one at a time, parses replies into fields, and saves the completed response as a row in a Sim table.',
    iconId: 'brand/telegram-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'telegram-6',
    blockType: 'telegram',
    label: 'Telegram + WhatsApp dual-channel notifier',
    prompt:
        'Build a workflow that sends critical operational alerts via both Telegram and WhatsApp based on user preference per recipient, and writes delivery status to a table.',
    iconId: 'brand/telegram-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'temporal-0',
    blockType: 'temporal',
    label: 'Temporal order approval gate',
    prompt:
        'Create a workflow that receives an approval decision from a form, signals the matching Temporal order workflow with the decision, and posts a confirmation to Slack with the workflow ID and current status.',
    iconId: 'brand/temporal-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'temporal-1',
    blockType: 'temporal',
    label: 'Temporal failed workflow digest',
    prompt:
        'Build a scheduled daily workflow that lists Temporal executions that failed or timed out in the last 24 hours, pulls the close event from each history to extract the failure, and posts a digest to Slack grouped by workflow type.',
    iconId: 'brand/temporal-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'temporal-2',
    blockType: 'temporal',
    label: 'Temporal stuck workflow watcher',
    prompt:
        'Create a scheduled workflow that lists running Temporal executions, describes each one to inspect pending activities, flags workflows whose activities are retrying with high attempt counts, and opens a Linear ticket with the failure details.',
    iconId: 'brand/temporal-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'temporal-3',
    blockType: 'temporal',
    label: 'Temporal kickoff from intake form',
    prompt:
        'Build a workflow that starts a Temporal workflow execution with input assembled from an intake form submission, polls describe until the execution closes, and writes the final status and timing to a tracking table.',
    iconId: 'brand/temporal-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'temporal-4',
    blockType: 'temporal',
    label: 'Temporal status lookup agent',
    prompt:
        'Create an agent that answers "where is my order" questions by querying the matching Temporal workflow for its current state and summarizing the progress, falling back to the latest history events when no query handler responds.',
    iconId: 'brand/temporal-icon',
    modules: <String>['agent'],
  ),
  SuggestionTemplate(
    id: 'temporal-5',
    blockType: 'temporal',
    label: 'Temporal runaway workflow janitor',
    prompt:
        'Build a scheduled weekly workflow that lists Temporal executions running longer than seven days, describes each to confirm it is stalled, requests cancellation with a recorded reason, and terminates any execution that ignores the cancellation after a grace period.',
    iconId: 'brand/temporal-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'temporal-6',
    blockType: 'temporal',
    label: 'Temporal incident escalation bridge',
    prompt:
        'Create a workflow that signals a Temporal incident-response workflow with escalation details when a monitoring alert fires, using signal-with-start so a new incident workflow is created if one is not already running.',
    iconId: 'brand/temporal-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'textract-0',
    blockType: 'textract',
    label: 'Textract invoice extractor',
    prompt:
        'Create a scheduled workflow that polls an S3 folder for new PDFs, runs AWS Textract to extract line items and totals, writes the structured fields to a table, and flags invoices that fail validation.',
    iconId: 'brand/textract-icon',
    modules: <String>['scheduled', 'tables', 'files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'textract-1',
    blockType: 'textract',
    label: 'Textract receipt OCR',
    prompt:
        'Build a workflow that processes Gmail attachments with AWS Textract, extracts vendor, date, total, and category, logs each receipt to an expense table, and tags reimbursable items.',
    iconId: 'brand/textract-icon',
    modules: <String>['tables', 'files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'textract-2',
    blockType: 'textract',
    label: 'Textract ID verification',
    prompt:
        'Build a workflow that runs uploaded ID documents through AWS Textract analyze-id, extracts name, DOB, and ID number, validates against a customer record, and flags mismatches for review.',
    iconId: 'brand/textract-icon',
    modules: <String>['tables', 'files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'textract-3',
    blockType: 'textract',
    label: 'Textract form-to-table',
    prompt:
        'Build a workflow that pushes scanned forms from Google Drive through AWS Textract analyze-document, extracts key-value pairs and tables, and writes structured rows to a Sim table for downstream automations.',
    iconId: 'brand/textract-icon',
    modules: <String>['tables', 'files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'textract-4',
    blockType: 'textract',
    label: 'Textract + Reducto cross-format extractor',
    prompt:
        'Create a workflow that ingests mixed PDF and image files, routes images through AWS Textract and dense PDFs through Reducto, normalizes fields, and writes rows to a table.',
    iconId: 'brand/textract-icon',
    modules: <String>['files', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'textract-5',
    blockType: 'textract',
    label: 'Textract + Extend pipeline composer',
    prompt:
        'Build a workflow that uses AWS Textract for layout-aware OCR and Extend for structured field extraction, fusing outputs into clean records for downstream automations.',
    iconId: 'brand/textract-icon',
    modules: <String>['files', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'textract-6',
    blockType: 'textract',
    label: 'Textract handwritten-note digitizer',
    prompt:
        'Build a workflow that runs scanned handwritten intake notes through AWS Textract, converts the recognized text into clean Markdown, indexes it into a knowledge base, and posts a confidence summary to Slack so low-confidence pages get a human review.',
    iconId: 'brand/textract-icon',
    modules: <String>['files', 'knowledge-base', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'thrive-0',
    blockType: 'thrive',
    label: 'Onboard new hires into Thrive',
    prompt:
        'Build a workflow that, when a new employee row is added to a Google Sheet, creates the user in Thrive with their ref, name, email, job title, and manager, then adds them to the relevant onboarding audience.',
    iconId: 'brand/thrive-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'thrive-1',
    blockType: 'thrive',
    label: 'Thrive compliance digest',
    prompt:
        'Create a scheduled weekly workflow that lists Thrive enrolments for a compliance assignment, filters those still open or overdue, and posts a Slack summary to the people-ops channel.',
    iconId: 'brand/thrive-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'thrive-2',
    blockType: 'thrive',
    label: 'Suspend leavers in Thrive',
    prompt:
        'Build a workflow that reads terminated employees from an HRIS export and suspends each matching user in Thrive with their end date, then logs the result to a table.',
    iconId: 'brand/thrive-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'thrive-3',
    blockType: 'thrive',
    label: 'Import completions into Thrive',
    prompt:
        'Create a workflow that reads a CSV of prior learning records and creates a completion in Thrive for each user and content item with the completion date.',
    iconId: 'brand/thrive-icon',
    modules: <String>['files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'thrive-4',
    blockType: 'thrive',
    label: 'Assign Thrive training to an audience',
    prompt:
        'Build a workflow that creates a Thrive content assignment for a chosen audience and primary content, sets a 30-day completion period, and reports how many learners were enrolled.',
    iconId: 'brand/thrive-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'thrive-5',
    blockType: 'thrive',
    label: 'Thrive CPD shortfall report',
    prompt:
        'Create a scheduled monthly workflow that queries Thrive CPD user summaries for a date range, compares logged minutes against each audience CPD requirement, and emails managers a list of learners below target.',
    iconId: 'brand/thrive-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'thrive-6',
    blockType: 'thrive',
    label: 'Tag Thrive learners by skill',
    prompt:
        'Build a workflow that searches Thrive users by status, then adds skill tags and updates skill levels for each learner based on a mapping in a spreadsheet.',
    iconId: 'brand/thrive-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'thrive-7',
    blockType: 'thrive',
    label: 'Thrive trending content to Slack',
    prompt:
        'Create a scheduled workflow that queries recently updated Thrive content and activity records, summarises the most engaged-with learning, and posts a weekly highlight to Slack.',
    iconId: 'brand/thrive-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tiktok-0',
    blockType: 'tiktok',
    label: 'TikTok content calendar drafts',
    prompt:
        'Create a scheduled workflow that reads the next due row from a Tables-based content calendar, uploads the matching video to the creator’s TikTok inbox as a draft, and notifies them to review and publish it in TikTok.',
    iconId: 'brand/tik-tok-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'tiktok',
  ),
  SuggestionTemplate(
    id: 'tiktok-1',
    blockType: 'tiktok',
    label: 'TikTok performance reporter',
    prompt:
        'Build a workflow that lists recent TikTok videos, summarizes view and engagement trends with an agent, and posts the digest to Slack every week.',
    iconId: 'brand/tik-tok-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'tiktok',
  ),
  SuggestionTemplate(
    id: 'tiktok-2',
    blockType: 'tiktok',
    label: 'TikTok draft review pipeline',
    prompt:
        'Create a workflow that uploads a new video to a TikTok inbox draft for review, then notifies the marketing team on Slack to approve and post it from the TikTok app.',
    iconId: 'brand/tik-tok-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'tiktok',
  ),
  SuggestionTemplate(
    id: 'tinybird-0',
    blockType: 'tinybird',
    label: 'Tinybird pipe-as-API endpoint',
    prompt:
        'Create a workflow that calls a Tinybird published pipe with parameters on a schedule, normalizes the results, and writes them into a Sim table for downstream consumers.',
    iconId: 'brand/tinybird-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tinybird-1',
    blockType: 'tinybird',
    label: 'Tinybird realtime metric watcher',
    prompt:
        'Build a workflow that polls a Tinybird pipe every minute for a realtime KPI, compares against a rolling baseline, and pages PagerDuty when the metric crosses a SLO threshold.',
    iconId: 'brand/tinybird-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tinybird-2',
    blockType: 'tinybird',
    label: 'Tinybird user-segment exporter',
    prompt:
        'Create a workflow that calls a Tinybird published endpoint with segment parameters, writes the user list to a table, and feeds it to a Loops campaign for targeted activation messaging.',
    iconId: 'brand/tinybird-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tinybird-3',
    blockType: 'tinybird',
    label: 'Tinybird usage-meter dashboard',
    prompt:
        'Build a workflow that exposes a Tinybird endpoint reporting per-customer usage for billing, refreshes a Sim table hourly, and surfaces top consumers to Slack.',
    iconId: 'brand/tinybird-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tinybird-4',
    blockType: 'tinybird',
    label: 'Tinybird funnel analytics digest',
    prompt:
        'Create a scheduled workflow that queries a Tinybird pipe for daily signup, activation, and conversion counts, calculates step-over-step drop-off, and posts a funnel digest with week-over-week deltas to the growth Slack channel.',
    iconId: 'brand/tinybird-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tinybird-5',
    blockType: 'tinybird',
    label: 'Tinybird anomaly investigator',
    prompt:
        'Build a workflow triggered by an alert that calls a Tinybird pipe to pull the surrounding event data for the affected metric, has an agent summarize the likely cause, and opens a Linear issue with the supporting query results attached.',
    iconId: 'brand/tinybird-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tinybird-6',
    blockType: 'tinybird',
    label: 'Tinybird executive KPI report',
    prompt:
        'Create a scheduled weekly workflow that queries several Tinybird pipes for the company’s headline KPIs, assembles them into a Markdown report file with trend commentary, and emails it to the leadership team.',
    iconId: 'brand/tinybird-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tinyfish-0',
    blockType: 'tinyfish',
    label: 'TinyFish competitor pricing watch',
    prompt:
        'Create a scheduled workflow that runs a TinyFish agent weekly against three competitor pricing pages, extracts every plan name and monthly price into a fixed output schema, diffs it against the table from last week, and posts the changes to Slack.',
    iconId: 'brand/tiny-fish-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tinyfish-1',
    blockType: 'tinyfish',
    label: 'TinyFish supplier portal collector',
    prompt:
        'Build a workflow that uses a TinyFish agent with vault credentials to log into supplier portals that have no API, download the outstanding invoices, and write the invoice metadata to a finance table.',
    iconId: 'brand/tiny-fish-icon',
    modules: <String>['scheduled', 'tables', 'files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tinyfish-2',
    blockType: 'tinyfish',
    label: 'TinyFish research briefing',
    prompt:
        'Create a workflow that uses TinyFish Search to find the top sources on a topic, fetches each one as clean markdown, and has an agent write a cited briefing to a file.',
    iconId: 'brand/tiny-fish-icon',
    modules: <String>['files', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tinyfish-3',
    blockType: 'tinyfish',
    label: 'TinyFish lead site enrichment',
    prompt:
        'Build a workflow that reads company domains from a table, fetches each homepage and pricing page with TinyFish, extracts positioning and price points into a schema, and writes the enriched rows back.',
    iconId: 'brand/tiny-fish-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tinyfish-4',
    blockType: 'tinyfish',
    label: 'TinyFish long-running run tracker',
    prompt:
        'Create a workflow that queues a TinyFish agent run asynchronously, stores the run ID in a table, and a second scheduled workflow that polls each open run, writes the extracted result back, and cancels runs older than an hour.',
    iconId: 'brand/tiny-fish-icon',
    modules: <String>['scheduled', 'tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tinyfish-5',
    blockType: 'tinyfish',
    label: 'TinyFish signup flow QA',
    prompt:
        'Build a workflow that runs a TinyFish agent in strict mode against the staging signup flow every morning, checks that account creation succeeds end to end, and opens a Linear issue with the failing step when it does not.',
    iconId: 'brand/tiny-fish-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tinyfish-6',
    blockType: 'tinyfish',
    label: 'TinyFish review monitor',
    prompt:
        'Create a scheduled workflow that uses TinyFish Search to find new reviews mentioning your product, fetches each review page, classifies sentiment with an agent, and writes notable reviews to a tracking table.',
    iconId: 'brand/tiny-fish-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'tinyfish-7',
    blockType: 'tinyfish',
    label: 'TinyFish regulatory filing digest',
    prompt:
        'Build a workflow that fetches a regulator’s notices page with TinyFish every morning, extracts new filings into a schema, and emails a digest of anything matching your watch list.',
    iconId: 'brand/tiny-fish-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'trello-0',
    blockType: 'trello',
    label: 'Trello card auto-router',
    prompt:
        'Build a scheduled workflow that polls a Trello inbox list, classifies each new card by topic, and moves it to the right list based on the classification.',
    iconId: 'brand/trello-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'trello',
  ),
  SuggestionTemplate(
    id: 'trello-1',
    blockType: 'trello',
    label: 'Trello + Linear bridge',
    prompt:
        'Create a workflow that mirrors Trello cards in a chosen list into Linear issues, keeps status and comments in sync, and writes the link back to the Trello card.',
    iconId: 'brand/trello-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'trello',
  ),
  SuggestionTemplate(
    id: 'trello-2',
    blockType: 'trello',
    label: 'Trello SLA monitor',
    prompt:
        'Build a workflow that watches Trello cards for due-date breaches, sends reminders, and escalates to managers via Slack when items slip more than 2 days.',
    iconId: 'brand/trello-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'trello',
  ),
  SuggestionTemplate(
    id: 'trello-3',
    blockType: 'trello',
    label: 'Trello content pipeline',
    prompt:
        'Create a workflow that reads a Trello editorial board, publishes the cards in the "ready" list to WordPress on schedule, and moves the card to "live" with the URL attached.',
    iconId: 'brand/trello-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'trello',
  ),
  SuggestionTemplate(
    id: 'trello-4',
    blockType: 'trello',
    label: 'Trello weekly digest',
    prompt:
        'Build a scheduled weekly workflow that summarizes Trello board movements — cards completed, blocked, in-progress — and emails the digest to the project owner.',
    iconId: 'brand/trello-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'trello',
  ),
  SuggestionTemplate(
    id: 'trello-5',
    blockType: 'trello',
    label: 'Trello stale-card sweeper',
    prompt:
        'Create a scheduled workflow that scans a Trello board for cards with no activity in 30 days, comments a nudge on each, and posts a stale-card list to Slack for the project owner.',
    iconId: 'brand/trello-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'trello',
  ),
  SuggestionTemplate(
    id: 'trello-6',
    blockType: 'trello',
    label: 'Trello onboarding seeder',
    prompt:
        'Build a workflow that creates the standard onboarding cards in a Trello list for each new hire, sets due dates by step, and tailors the card set to their role.',
    iconId: 'brand/trello-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'trello',
  ),
  SuggestionTemplate(
    id: 'trigger_dev-0',
    blockType: 'trigger_dev',
    label: 'Trigger.dev job kickoff',
    prompt:
        'Build a workflow that receives an event from another system, triggers the matching Trigger.dev background task with a JSON payload, and returns the run ID for tracking.',
    iconId: 'brand/trigger-dev-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'trigger_dev-1',
    blockType: 'trigger_dev',
    label: 'Trigger.dev failed-run monitor',
    prompt:
        'Build a scheduled workflow that lists Trigger.dev runs with status FAILED or CRASHED from the last hour, summarizes the failures per task, and posts a digest to the engineering Slack channel.',
    iconId: 'brand/trigger-dev-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'trigger_dev-2',
    blockType: 'trigger_dev',
    label: 'Trigger.dev auto-retry agent',
    prompt:
        'Create an agent that lists failed Trigger.dev runs, inspects each run error to decide whether the failure looks transient, and replays the runs that are safe to retry.',
    iconId: 'brand/trigger-dev-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'trigger_dev-3',
    blockType: 'trigger_dev',
    label: 'Trigger.dev run-output collector',
    prompt:
        'Build a workflow that triggers a Trigger.dev task, polls Get Run until the run completes, and writes the run output and timing details into a results table.',
    iconId: 'brand/trigger-dev-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'trigger_dev-4',
    blockType: 'trigger_dev',
    label: 'Trigger.dev schedule manager',
    prompt:
        'Create an agent that manages Trigger.dev cron schedules per customer — creating a schedule with the customer ID as external ID on signup, and deactivating or deleting it on churn.',
    iconId: 'brand/trigger-dev-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'trigger_dev-5',
    blockType: 'trigger_dev',
    label: 'Trigger.dev stuck-run janitor',
    prompt:
        'Build a scheduled workflow that lists Trigger.dev runs still executing past their expected duration, cancels the stuck runs, and posts the canceled run IDs to Slack.',
    iconId: 'brand/trigger-dev-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'trigger_dev-6',
    blockType: 'trigger_dev',
    label: 'Trigger.dev compute cost reporter',
    prompt:
        'Create a weekly scheduled workflow that uses Trigger.dev Execute Query to aggregate compute cost and duration per task for the past week, and emails a cost report to the team.',
    iconId: 'brand/trigger-dev-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'trigger_dev-7',
    blockType: 'trigger_dev',
    label: 'Trigger.dev human approval gate',
    prompt:
        'Build a workflow where a Trigger.dev task waits on a waitpoint token, an approver reviews the request in Slack, and the workflow completes the waitpoint token with the approval decision so the task resumes.',
    iconId: 'brand/trigger-dev-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'trigger_dev-8',
    blockType: 'trigger_dev',
    label: 'Trigger.dev deploy watchdog',
    prompt:
        'Create a workflow that checks the latest Trigger.dev deployment after each release, and if the deployment failed or new runs start crashing, promotes the previous deployment version and alerts the on-call channel.',
    iconId: 'brand/trigger-dev-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'twilio_sms-0',
    blockType: 'twilio_sms',
    label: 'Twilio appointment reminders',
    prompt:
        'Build a scheduled workflow that reads tomorrow’s appointments from a table and sends each customer a personalized Twilio SMS reminder with the time and a reschedule link.',
    iconId: 'brand/twilio-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'twilio_sms-1',
    blockType: 'twilio_sms',
    label: 'Twilio order-status notifier',
    prompt:
        'Create a workflow triggered when an order ships that looks up the customer’s phone number and sends a Twilio SMS with the tracking number and estimated delivery date.',
    iconId: 'brand/twilio-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'twilio_sms-2',
    blockType: 'twilio_sms',
    label: 'Twilio incident escalation alerts',
    prompt:
        'Build a workflow triggered by a PagerDuty incident that sends a Twilio SMS to the on-call engineer with the service name and severity so critical alerts reach them even when they are away from Slack.',
    iconId: 'brand/twilio-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'twilio_sms-3',
    blockType: 'twilio_sms',
    label: 'Twilio lead speed-to-text',
    prompt:
        'Create a workflow that fires when a new lead submits a form, drafts a friendly intro message, and sends it via Twilio SMS within seconds so reps engage hot leads while they are still interested.',
    iconId: 'brand/twilio-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'twilio_sms-4',
    blockType: 'twilio_sms',
    label: 'Twilio two-factor code sender',
    prompt:
        'Build a workflow that receives a verification request from an application, generates a one-time code, sends it to the user via Twilio SMS, and logs the send for audit.',
    iconId: 'brand/twilio-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'twilio_sms-5',
    blockType: 'twilio_sms',
    label: 'Twilio payment-failure outreach',
    prompt:
        'Create a workflow triggered by a Stripe failed-payment event that sends the customer a Twilio SMS with a secure update-payment link and logs the recovery attempt to a table.',
    iconId: 'brand/twilio-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'twilio_sms-6',
    blockType: 'twilio_sms',
    label: 'Twilio daily standup nudge',
    prompt:
        'Build a scheduled workflow that sends each team member a Twilio SMS prompting their async standup update every weekday morning, with a link to where to post it.',
    iconId: 'brand/twilio-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'twilio_voice-0',
    blockType: 'twilio_voice',
    label: 'Twilio Voice IVR router',
    prompt:
        'Create a workflow that handles inbound Twilio Voice calls with an IVR menu, captures caller intent, routes to the right queue, and writes the call summary to a support table.',
    iconId: 'brand/twilio-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'twilio_voice-1',
    blockType: 'twilio_voice',
    label: 'Twilio Voice outbound dialer',
    prompt:
        'Build a workflow that reads a callbacks table, places Twilio Voice calls in batches, plays a recorded message or connects to an agent, and logs the call outcome back to the row.',
    iconId: 'brand/twilio-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'twilio_voice-2',
    blockType: 'twilio_voice',
    label: 'Twilio Voice incident dialer',
    prompt:
        'Create a workflow that on a PagerDuty severity-1 incident places a Twilio Voice call to the on-call engineer with an automated message, escalates to backup if no answer, and logs the cascade.',
    iconId: 'brand/twilio-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'twilio_voice-3',
    blockType: 'twilio_voice',
    label: 'Twilio Voice transcript-to-CRM',
    prompt:
        'Build a workflow that runs after a Twilio Voice call ends, transcribes the recording, summarizes the conversation, and writes the summary plus action items to the linked Salesforce account.',
    iconId: 'brand/twilio-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'twilio_voice-4',
    blockType: 'twilio_voice',
    label: 'Twilio Voice survey collector',
    prompt:
        'Create a workflow that places Twilio Voice survey calls to recent customers, captures their NPS rating via key press, and writes results to a feedback table for analysis.',
    iconId: 'brand/twilio-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'twilio_voice-5',
    blockType: 'twilio_voice',
    label: 'Twilio Voice spam-call filter',
    prompt:
        'Build a workflow that screens inbound Twilio Voice calls, classifies likely spam using number reputation plus a spoken challenge captured via Gather DTMF — press a digit to continue — and routes only verified callers to the support queue.',
    iconId: 'brand/twilio-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'twilio_voice-6',
    blockType: 'twilio_voice',
    label: 'Twilio Voice call QA reviewer',
    prompt:
        'Create a scheduled workflow that lists yesterday\'s Twilio Voice calls, pulls each recording, transcribes and scores it for tone, compliance phrases, and resolution, and writes a QA scorecard to a table while flagging low-scoring calls to the team lead in Slack.',
    iconId: 'brand/twilio-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'typeform-0',
    blockType: 'typeform',
    label: 'Typeform survey summarizer',
    prompt:
        'Create a workflow that pulls new Typeform responses daily, categorizes feedback by theme and sentiment, logs structured results to a table, and sends a Slack digest when a new batch of responses comes in with the key takeaways.',
    iconId: 'brand/typeform-icon',
    modules: <String>['tables', 'scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'typeform-1',
    blockType: 'typeform',
    label: 'Typeform NPS pipeline',
    prompt:
        'Build a workflow that collects Typeform NPS responses, classifies each as promoter/passive/detractor, writes the rolled-up score to a tracking table, and pings Slack on detractor spikes.',
    iconId: 'brand/typeform-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'typeform-2',
    blockType: 'typeform',
    label: 'Typeform lead enricher',
    prompt:
        'Create a workflow that watches Typeform lead-gen submissions, enriches each lead with company size and tech stack via Apollo, and pushes the enriched lead into Salesforce.',
    iconId: 'brand/typeform-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'typeform-3',
    blockType: 'typeform',
    label: 'Typeform candidate screener',
    prompt:
        'Build a workflow that captures Typeform applicant responses, scores them against the role rubric with an agent, and creates a Greenhouse candidate with the score attached.',
    iconId: 'brand/typeform-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'typeform-4',
    blockType: 'typeform',
    label: 'Typeform event survey analyzer',
    prompt:
        'Create a workflow that processes Typeform event survey responses, summarizes feedback themes, writes structured insights to a feedback table, and emails the organizer the digest.',
    iconId: 'brand/typeform-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'typeform-5',
    blockType: 'typeform',
    label: 'Typeform onboarding follow-up',
    prompt:
        'Build a workflow that collects Typeform onboarding-flow responses, segments responders by job-to-be-done, and triggers tailored Loops email sequences for each segment.',
    iconId: 'brand/typeform-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'typeform-6',
    blockType: 'typeform',
    label: 'Typeform research analyzer',
    prompt:
        'Create a workflow that pulls Typeform research responses, clusters answers by theme, and writes a tables-based research insight log for the product team.',
    iconId: 'brand/typeform-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'upstash-0',
    blockType: 'upstash',
    label: 'Upstash key TTL hygiene',
    prompt:
        'Build a scheduled workflow that pulls Upstash Redis keys without TTLs, flags those that should expire, and either sets a TTL or routes to engineering for review.',
    iconId: 'brand/upstash-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'upstash-1',
    blockType: 'upstash',
    label: 'Upstash counter digest',
    prompt:
        'Create a scheduled daily workflow that reads Upstash Redis counter keys for the day, summarizes the totals, and posts a usage digest to Slack.',
    iconId: 'brand/upstash-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'upstash-2',
    blockType: 'upstash',
    label: 'Upstash queue drain',
    prompt:
        'Build a scheduled workflow that pops queued jobs from an Upstash Redis list with LRANGE, transforms each into structured rows, and writes them into a downstream Sim table for further automation.',
    iconId: 'brand/upstash-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'upstash-3',
    blockType: 'upstash',
    label: 'Upstash + Vercel cache invalidator',
    prompt:
        'Create a workflow triggered by a Vercel production deploy that flushes targeted Upstash cache keys for changed routes, so users never see stale responses post-deploy.',
    iconId: 'brand/upstash-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'upstash-4',
    blockType: 'upstash',
    label: 'Upstash key integrity check',
    prompt:
        'Build a scheduled workflow that reads a set of critical Upstash Redis keys, compares each value against the expected baseline in a table, and writes a mismatch report to an SRE audit table.',
    iconId: 'brand/upstash-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'upstash-5',
    blockType: 'upstash',
    label: 'Upstash cache warmer',
    prompt:
        'Create a scheduled workflow that precomputes expensive query results and writes them into Upstash Redis with a TTL using SET, so hot paths stay warm and pages PagerDuty if a warm-up run fails.',
    iconId: 'brand/upstash-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'upstash-6',
    blockType: 'upstash',
    label: 'Upstash + DynamoDB hybrid store',
    prompt:
        'Create a workflow that uses Upstash for hot keys and DynamoDB for cold storage, transparently promotes/demotes records based on access frequency.',
    iconId: 'brand/upstash-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'uptimerobot-0',
    blockType: 'uptimerobot',
    label: 'UptimeRobot downtime alert to Slack',
    prompt:
        'Build a scheduled workflow that lists UptimeRobot incidents from the last hour, filters to ones that are still active, and posts a formatted Slack alert with the affected monitor name, cause, and how long it has been down.',
    iconId: 'brand/uptime-robot-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'uptimerobot-1',
    blockType: 'uptimerobot',
    label: 'UptimeRobot monitors from a table',
    prompt:
        'Create a workflow that reads a list of service URLs from a table and creates an HTTP UptimeRobot monitor for each one with a 5-minute interval, then writes the new monitor IDs back to the table.',
    iconId: 'brand/uptime-robot-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'uptimerobot-2',
    blockType: 'uptimerobot',
    label: 'UptimeRobot incident to Linear',
    prompt:
        'Build a scheduled workflow that polls UptimeRobot for active incidents, and for any new incident creates a Linear ticket with the monitor name, cause, and root-cause URL, then posts the ticket link to Slack.',
    iconId: 'brand/uptime-robot-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'uptimerobot-3',
    blockType: 'uptimerobot',
    label: 'UptimeRobot maintenance window',
    prompt:
        'Create a workflow that, before a planned deploy, creates a one-time UptimeRobot maintenance window covering the affected monitors for the next 30 minutes so alerts are suppressed during the rollout.',
    iconId: 'brand/uptime-robot-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'uptimerobot-4',
    blockType: 'uptimerobot',
    label: 'Daily UptimeRobot digest',
    prompt:
        'Build a scheduled daily workflow that lists all UptimeRobot monitors, summarizes how many are up versus down, lists any currently in a down state, and emails a morning availability digest to the on-call team.',
    iconId: 'brand/uptime-robot-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'uptimerobot-5',
    blockType: 'uptimerobot',
    label: 'UptimeRobot status page',
    prompt:
        'Create a workflow that builds a public status page in UptimeRobot for a chosen set of monitors, uploads the company logo, and returns the public URL key so it can be shared.',
    iconId: 'brand/uptime-robot-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'uptimerobot-6',
    blockType: 'uptimerobot',
    label: 'Pause UptimeRobot monitors',
    prompt:
        'Build a workflow that, when triggered, pauses a specific UptimeRobot monitor, waits for an upstream maintenance task to finish, then starts the monitor again and confirms it is back to a running state.',
    iconId: 'brand/uptime-robot-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'uptimerobot-7',
    blockType: 'uptimerobot',
    label: 'Onboard UptimeRobot contacts',
    prompt:
        'Create a workflow that reads a list of team email addresses and adds each one as an UptimeRobot alert contact, then assigns them to the critical production monitors.',
    iconId: 'brand/uptime-robot-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'vanta-0',
    blockType: 'vanta',
    label: 'Vanta failing test alerts',
    prompt:
        'Create a scheduled workflow that lists Vanta tests with status NEEDS_ATTENTION each morning, fetches the failing entities for each test, and posts a remediation digest to a Slack channel.',
    iconId: 'brand/vanta-icon',
    modules: <String>['scheduled', 'workflows'],
    providerId: 'vanta',
  ),
  SuggestionTemplate(
    id: 'vanta-1',
    blockType: 'vanta',
    label: 'Vanta evidence uploader',
    prompt:
        'Build a workflow that takes a generated report file, uploads it as evidence to the matching Vanta document with a description and effective date, and then submits the document collection for review.',
    iconId: 'brand/vanta-icon',
    modules: <String>['files', 'workflows'],
    providerId: 'vanta',
  ),
  SuggestionTemplate(
    id: 'vanta-2',
    blockType: 'vanta',
    label: 'Vanta vulnerability SLA watcher',
    prompt:
        'Create a scheduled workflow that lists Vanta vulnerabilities with SLA deadlines in the next 7 days, groups them by severity and vulnerable asset, and emails the security team a prioritized remediation list.',
    iconId: 'brand/vanta-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'vanta',
  ),
  SuggestionTemplate(
    id: 'vanta-3',
    blockType: 'vanta',
    label: 'Vanta compliance status report',
    prompt:
        'Build a scheduled workflow that lists Vanta frameworks with their control and test completion counts, has an agent summarize progress and gaps per framework, and writes a weekly compliance report to a table.',
    iconId: 'brand/vanta-icon',
    modules: <String>['scheduled', 'agent', 'tables', 'workflows'],
    providerId: 'vanta',
  ),
  SuggestionTemplate(
    id: 'vanta-4',
    blockType: 'vanta',
    label: 'Vanta onboarding task chaser',
    prompt:
        'Create a scheduled workflow that lists current Vanta people with overdue security tasks and sends each person a direct Slack reminder with their task summary status and due date, asking them to review outstanding tasks in Vanta.',
    iconId: 'brand/vanta-icon',
    modules: <String>['scheduled', 'workflows'],
    providerId: 'vanta',
  ),
  SuggestionTemplate(
    id: 'vanta-5',
    blockType: 'vanta',
    label: 'Vanta vendor review pipeline',
    prompt:
        'Build a scheduled workflow that lists Vanta vendors whose next security review is due within 30 days, looks up each vendor’s risk levels and contract dates, and creates a review task in the team’s project tracker.',
    iconId: 'brand/vanta-icon',
    modules: <String>['scheduled', 'workflows'],
    providerId: 'vanta',
  ),
  SuggestionTemplate(
    id: 'vanta-6',
    blockType: 'vanta',
    label: 'Vanta compliance Q&A agent',
    prompt:
        'Create an agent that answers compliance questions by querying Vanta: it can look up framework progress, control status, failing tests and their entities, policy approval status, and risk scenarios, and grounds every answer in the returned data.',
    iconId: 'brand/vanta-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'vanta',
  ),
  SuggestionTemplate(
    id: 'vercel-0',
    blockType: 'vercel',
    label: 'Vercel deployment monitor',
    prompt:
        'Build a scheduled workflow that polls Vercel for the latest deployments across my projects every five minutes, detects failed or stuck builds, fetches the build logs, summarizes the failure cause, and posts an actionable alert to Slack with a deep link to the deployment.',
    iconId: 'brand/vercel-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'vercel-1',
    blockType: 'vercel',
    label: 'Vercel preview deploy reviewer',
    prompt:
        'Build a workflow that watches GitHub pull requests, finds the matching Vercel preview deployment, captures the preview URL, runs a smoke check against critical pages, and posts a status comment on the pull request with the preview link and any issues found.',
    iconId: 'brand/vercel-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'vercel-2',
    blockType: 'vercel',
    label: 'Vercel env variable auditor',
    prompt:
        'Create a scheduled weekly workflow that pulls environment variables from every Vercel project, compares them to a reference list in a table, flags drift, missing keys, and stale values, and emails a remediation report to the platform team.',
    iconId: 'brand/vercel-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'vercel-3',
    blockType: 'vercel',
    label: 'Vercel domain and DNS inventory',
    prompt:
        'Build a scheduled workflow that lists every domain and DNS record across my Vercel account weekly, logs them into a tracking table, and sends a Slack diff of any added, removed, or modified records so DNS changes never go unnoticed.',
    iconId: 'brand/vercel-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'vercel-4',
    blockType: 'vercel',
    label: 'Vercel project pause guard',
    prompt:
        'Build a scheduled workflow that scans Vercel projects daily for low-traffic or stale candidates flagged in a table, pauses projects that meet the criteria, and Slacks a digest of paused and unpaused projects to the platform team for review.',
    iconId: 'brand/vercel-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'vercel-5',
    blockType: 'vercel',
    label: 'Vercel deploy log triage',
    prompt:
        'Create a workflow that fires after each Vercel deployment, fetches the build and runtime logs, classifies warnings and errors with an agent, groups recurring issues, and opens a Linear ticket per cluster so platform regressions get addressed early.',
    iconId: 'brand/vercel-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'vercel-6',
    blockType: 'vercel',
    label: 'Vercel failed deploy recovery',
    prompt:
        'Build a workflow that watches Vercel for failed production deployments, identifies the last known good production deployment, promotes it back to production for an instant rollback, and posts a Slack incident summary with the failure cause and rollback confirmation.',
    iconId: 'brand/vercel-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'wealthbox-0',
    blockType: 'wealthbox',
    label: 'Wealthbox CRM mirror',
    prompt:
        'Build a scheduled workflow that reads the Wealthbox contacts and tasks listed by ID in a Sim table, refreshes each row with the latest details, and keeps the table in sync for unified reporting.',
    iconId: 'brand/wealthbox-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'wealthbox',
  ),
  SuggestionTemplate(
    id: 'wealthbox-1',
    blockType: 'wealthbox',
    label: 'Wealthbox client review prep',
    prompt:
        'Create a workflow that runs the morning of each Wealthbox client meeting, gathers recent emails, notes, and tasks for that client, and emails the advisor a prep brief.',
    iconId: 'brand/wealthbox-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'wealthbox',
  ),
  SuggestionTemplate(
    id: 'wealthbox-2',
    blockType: 'wealthbox',
    label: 'Wealthbox task auto-creator',
    prompt:
        'Build a workflow that listens for Gmail messages tagged "client action", classifies the action, and creates a matching task on the Wealthbox client record.',
    iconId: 'brand/wealthbox-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'wealthbox',
  ),
  SuggestionTemplate(
    id: 'wealthbox-3',
    blockType: 'wealthbox',
    label: 'Wealthbox compliance audit',
    prompt:
        'Create a scheduled workflow that reads each Wealthbox contact listed in a tracking table monthly, checks for missing KYC fields or stale notes, and writes a compliance backlog to a table.',
    iconId: 'brand/wealthbox-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'wealthbox',
  ),
  SuggestionTemplate(
    id: 'wealthbox-4',
    blockType: 'wealthbox',
    label: 'Wealthbox birthday reminder',
    prompt:
        'Build a scheduled workflow that runs daily, reads the Wealthbox contacts tracked in a table to find birthdays in the next 7 days, and emails advisors a reminder with a personalized message draft.',
    iconId: 'brand/wealthbox-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'wealthbox',
  ),
  SuggestionTemplate(
    id: 'wealthbox-5',
    blockType: 'wealthbox',
    label: 'Wealthbox book-of-business digest',
    prompt:
        'Create a scheduled weekly workflow that reads the contacts and open tasks for each advisor from a tracking table, summarizes the book-of-business activity, and posts the digest to leadership in Slack.',
    iconId: 'brand/wealthbox-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'wealthbox',
  ),
  SuggestionTemplate(
    id: 'wealthbox-6',
    blockType: 'wealthbox',
    label: 'Wealthbox referral tracker',
    prompt:
        'Build a scheduled workflow that polls Wealthbox notes for new referrals, captures the source and prospect, writes the referral chain into a CRM table, and pings the advisor in Slack.',
    iconId: 'brand/wealthbox-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'wealthbox',
  ),
  SuggestionTemplate(
    id: 'webflow-0',
    blockType: 'webflow',
    label: 'Webflow lead capture pipeline',
    prompt:
        'Create a workflow that monitors new Webflow form submissions, enriches each lead with company and contact data using Apollo and web search, adds them to a tracking table with a lead score, and sends a Slack notification to the sales team for high-potential leads.',
    iconId: 'brand/webflow-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'webflow',
  ),
  SuggestionTemplate(
    id: 'webflow-1',
    blockType: 'webflow',
    label: 'Webflow CMS publisher',
    prompt:
        'Create a workflow that reads a draft articles table, generates an SEO-optimized post, publishes it as a Webflow CMS item, and writes the live URL back to the row.',
    iconId: 'brand/webflow-icon',
    modules: <String>['tables', 'agent', 'workflows'],
    providerId: 'webflow',
  ),
  SuggestionTemplate(
    id: 'webflow-2',
    blockType: 'webflow',
    label: 'Webflow form-to-CRM',
    prompt:
        'Build a workflow that watches Webflow form submissions, enriches each with Apollo company data, and pushes qualifying leads into HubSpot with the right owner and source.',
    iconId: 'brand/webflow-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'webflow',
  ),
  SuggestionTemplate(
    id: 'webflow-3',
    blockType: 'webflow',
    label: 'Webflow content auditor',
    prompt:
        'Create a scheduled monthly workflow that audits Webflow CMS items for missing meta descriptions, broken links, or stale dates, and writes a remediation backlog.',
    iconId: 'brand/webflow-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'webflow',
  ),
  SuggestionTemplate(
    id: 'webflow-4',
    blockType: 'webflow',
    label: 'Webflow CMS backup',
    prompt:
        'Build a scheduled workflow that exports every item from a Webflow CMS collection to S3 nightly with versioning, and writes the backup manifest to a tracking table.',
    iconId: 'brand/webflow-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'webflow',
  ),
  SuggestionTemplate(
    id: 'webflow-5',
    blockType: 'webflow',
    label: 'Webflow product catalog sync',
    prompt:
        'Create a scheduled workflow that mirrors Shopify products and pricing into a Webflow CMS product collection, keeps both in sync, and posts conflict alerts to Slack.',
    iconId: 'brand/webflow-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'webflow',
  ),
  SuggestionTemplate(
    id: 'webflow-6',
    blockType: 'webflow',
    label: 'Webflow + Hubspot lead-magnet',
    prompt:
        'Build a workflow that triggers on a Webflow form submission for a lead magnet, sends the asset via Loops, and writes the engagement to the matching HubSpot contact.',
    iconId: 'brand/webflow-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'webflow',
  ),
  SuggestionTemplate(
    id: 'whatsapp-0',
    blockType: 'whatsapp',
    label: 'WhatsApp appointment confirmations',
    prompt:
        'Build a workflow that reads upcoming Google Calendar appointments each morning and sends a WhatsApp confirmation with date, time, and a one-tap reschedule link.',
    iconId: 'brand/whats-app-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'whatsapp-1',
    blockType: 'whatsapp',
    label: 'WhatsApp order tracking',
    prompt:
        'Create a workflow that watches Shopify shipment events and sends customers a WhatsApp message with the tracking number, ETA, and a follow-up review request after delivery.',
    iconId: 'brand/whats-app-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'whatsapp-2',
    blockType: 'whatsapp',
    label: 'WhatsApp customer support agent',
    prompt:
        'Build a WhatsApp business agent that answers customer questions using a knowledge base, hands off to a human in Zendesk on complex tickets, and writes the conversation back to the contact record.',
    iconId: 'brand/whats-app-icon',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'whatsapp-3',
    blockType: 'whatsapp',
    label: 'WhatsApp lead qualifier',
    prompt:
        'Create a workflow that engages new leads via WhatsApp with a guided qualification script, scores them based on responses, and pushes qualified leads into Salesforce with the conversation log attached.',
    iconId: 'brand/whats-app-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'whatsapp-4',
    blockType: 'whatsapp',
    label: 'WhatsApp campaign sender',
    prompt:
        'Build a workflow that reads a segmented audience from a table and sends a personalized WhatsApp template message to each, throttling to stay under provider limits.',
    iconId: 'brand/whats-app-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'whatsapp-5',
    blockType: 'whatsapp',
    label: 'WhatsApp event RSVP collector',
    prompt:
        'Create a workflow that messages contacts about an upcoming event on WhatsApp, parses yes/no/maybe replies, and updates the RSVP table with the attendee count and dietary notes.',
    iconId: 'brand/whats-app-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'whatsapp-6',
    blockType: 'whatsapp',
    label: 'WhatsApp + Zoom meeting confirmer',
    prompt:
        'Build a workflow that sends a WhatsApp confirmation when a Zoom meeting is booked, with the join link and a one-tap reschedule option for the attendee.',
    iconId: 'brand/whats-app-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'wikipedia-0',
    blockType: 'wikipedia',
    label: 'Wikipedia background-research helper',
    prompt:
        'Build a workflow that for a chosen topic queries Wikipedia, extracts the lead and infobox, and writes a structured background brief file for the user.',
    iconId: 'brand/wikipedia-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'wikipedia-1',
    blockType: 'wikipedia',
    label: 'Wikipedia entity disambiguator',
    prompt:
        'Create a workflow that for an ambiguous person or company name queries Wikipedia, identifies the most likely entity given context, and writes the canonical reference back.',
    iconId: 'brand/wikipedia-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'wikipedia-2',
    blockType: 'wikipedia',
    label: 'Wikipedia knowledge-base seeder',
    prompt:
        'Build a workflow that for tracked topics fetches Wikipedia articles, chunks and embeds them, and seeds a knowledge base with canonical context.',
    iconId: 'brand/wikipedia-icon',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'wikipedia-3',
    blockType: 'wikipedia',
    label: 'Wikipedia citation validator',
    prompt:
        'Create a workflow that checks if claims drafted by an agent are supported by Wikipedia content, flags claims without strong sources, and writes a quality score.',
    iconId: 'brand/wikipedia-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'wikipedia-4',
    blockType: 'wikipedia',
    label: 'Wikipedia infobox extractor',
    prompt:
        'Build a workflow that takes a list of entity names, extracts the Wikipedia infobox fields for each, and writes structured rows for downstream analytics.',
    iconId: 'brand/wikipedia-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'wikipedia-5',
    blockType: 'wikipedia',
    label: 'Wikipedia related-topic graph',
    prompt:
        'Create a workflow that for a topic explores related Wikipedia pages, builds a topic graph in Neo4j, and surfaces adjacent themes.',
    iconId: 'brand/wikipedia-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'wikipedia-6',
    blockType: 'wikipedia',
    label: 'Wikipedia summary alerter',
    prompt:
        'Build a scheduled workflow that monitors Wikipedia pages for tracked entities, detects significant edits, and posts a summary diff to Slack.',
    iconId: 'brand/wikipedia-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'windchill-0',
    blockType: 'windchill',
    label: 'Windchill document approval intake',
    prompt:
        'Build a workflow that creates a Windchill document from an approved intake form, uploads its primary content, and sends the resulting document identifier to the requester.',
    iconId: 'brand/windchill-icon',
    modules: <String>['files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'windchill-1',
    blockType: 'windchill',
    label: 'Windchill lifecycle readiness review',
    prompt:
        'Create a workflow that reads a Windchill document and its valid lifecycle transitions, checks required metadata, and produces a readiness report before release.',
    iconId: 'brand/windchill-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'windchill-2',
    blockType: 'windchill',
    label: 'Windchill structure change summary',
    prompt:
        'Build a workflow that retrieves a Windchill document structure and generates a concise summary of child-document names, versions, states, and missing metadata.',
    iconId: 'brand/windchill-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'windchill-3',
    blockType: 'windchill',
    label: 'Windchill controlled document release',
    prompt:
        'Create a workflow that checks in a Windchill document, validates an allowed lifecycle transition, and moves it to the approved release state.',
    iconId: 'brand/windchill-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'windchill-4',
    blockType: 'windchill',
    label: 'Windchill attachment package',
    prompt:
        'Build a workflow that uploads a set of inspection files as Windchill document attachments and returns the accepted file names for an audit record.',
    iconId: 'brand/windchill-icon',
    modules: <String>['files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'windchill-5',
    blockType: 'windchill',
    label: 'Windchill revision preparation',
    prompt:
        'Create a workflow that checks out a Windchill document, updates selected attributes, checks it in with notes, and revises it for the next change cycle.',
    iconId: 'brand/windchill-icon',
    modules: <String>['workflows'],
  ),
  SuggestionTemplate(
    id: 'windchill-6',
    blockType: 'windchill',
    label: 'Windchill document inventory',
    prompt:
        'Build a scheduled workflow that pages through Windchill documents, records their numbers, versions, states, and folder locations in a table, and flags stale checked-out documents.',
    iconId: 'brand/windchill-icon',
    modules: <String>['scheduled', 'tables', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'wiza-0',
    blockType: 'wiza',
    label: 'Wiza prospect builder',
    prompt:
        'Build a workflow that runs a Wiza prospect search against my ICP filters, reveals verified emails and phone numbers for each match, and writes the prospect list into a sender table.',
    iconId: 'brand/wiza-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'wiza-1',
    blockType: 'wiza',
    label: 'Wiza contact reveal',
    prompt:
        'Create a workflow that watches a leads table for new rows, runs a Wiza individual reveal to surface verified email and phone, and writes the contact details back to each row.',
    iconId: 'brand/wiza-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'wiza-2',
    blockType: 'wiza',
    label: 'Wiza company enricher',
    prompt:
        'Build a workflow that takes a list of company domains, runs Wiza company enrichment, and writes firmographics and headcount into a tables-based research base.',
    iconId: 'brand/wiza-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'wiza-3',
    blockType: 'wiza',
    label: 'Wiza + Email Bison outbound',
    prompt:
        'Create a workflow that uses Wiza to find and reveal verified prospect emails, drafts a personalized first-touch message, and pushes valid prospects into an Email Bison campaign.',
    iconId: 'brand/wiza-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'wiza-4',
    blockType: 'wiza',
    label: 'Wiza CRM gap-filler',
    prompt:
        'Build a scheduled workflow that finds Salesforce contacts missing verified phone numbers, runs a Wiza reveal to fill the gaps, and updates each contact record.',
    iconId: 'brand/wiza-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'wiza-5',
    blockType: 'wiza',
    label: 'Wiza credit monitor',
    prompt:
        'Create a scheduled workflow that checks the remaining Wiza credit balance each morning, logs the daily usage to a table, and posts a Slack alert when credits fall below the threshold so reveals never silently stall mid-campaign.',
    iconId: 'brand/wiza-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'wiza-6',
    blockType: 'wiza',
    label: 'Wiza to HubSpot pipeline',
    prompt:
        'Build a workflow that runs a Wiza prospect search for my target segment, reveals verified emails and phones for each match, and creates or updates the matching HubSpot contacts with the enriched fields and a lead-source tag.',
    iconId: 'brand/wiza-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'wordpress-0',
    blockType: 'wordpress',
    label: 'WordPress blog auto-publisher',
    prompt:
        'Build a workflow that takes a draft document, optimizes it for SEO by researching target keywords, formats it for WordPress with proper headings and meta description, and publishes it as a draft post for final review.',
    iconId: 'brand/wordpress-icon',
    modules: <String>['agent', 'files', 'workflows'],
    providerId: 'wordpress',
  ),
  SuggestionTemplate(
    id: 'wordpress-1',
    blockType: 'wordpress',
    label: 'WordPress release-notes publisher',
    prompt:
        'Create a scheduled workflow that runs every Friday, pulls merged GitHub PRs for the week, drafts a user-facing changelog, and publishes it as a WordPress post.',
    iconId: 'brand/wordpress-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'wordpress',
  ),
  SuggestionTemplate(
    id: 'wordpress-2',
    blockType: 'wordpress',
    label: 'WordPress comment moderator',
    prompt:
        'Build a scheduled workflow that polls new WordPress comments, classifies each as spam, question, or constructive, auto-moderates spam, and replies to questions using a knowledge base.',
    iconId: 'brand/wordpress-icon',
    modules: <String>['scheduled', 'knowledge-base', 'agent', 'workflows'],
    providerId: 'wordpress',
  ),
  SuggestionTemplate(
    id: 'wordpress-3',
    blockType: 'wordpress',
    label: 'WordPress SEO refresher',
    prompt:
        'Create a scheduled monthly workflow that finds underperforming WordPress posts, runs Ahrefs keyword analysis, drafts refreshed sections, and stages the update as a draft revision.',
    iconId: 'brand/wordpress-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'wordpress',
  ),
  SuggestionTemplate(
    id: 'wordpress-4',
    blockType: 'wordpress',
    label: 'WordPress newsletter republisher',
    prompt:
        'Build a workflow that publishes a new WordPress post and then drafts an adapted Mailchimp newsletter version, links back to the post, and queues it for the editor’s review.',
    iconId: 'brand/wordpress-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'wordpress',
  ),
  SuggestionTemplate(
    id: 'wordpress-5',
    blockType: 'wordpress',
    label: 'WordPress broken-link sweeper',
    prompt:
        'Create a scheduled workflow that scans WordPress posts for broken outbound links, proposes replacement URLs via web search, and stages each as a draft revision for approval.',
    iconId: 'brand/wordpress-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'wordpress',
  ),
  SuggestionTemplate(
    id: 'wordpress-6',
    blockType: 'wordpress',
    label: 'WordPress media-rich post builder',
    prompt:
        'Build a workflow that takes a draft article and its image files, uploads each image to the WordPress media library, generates a hero image with an image generator, assigns the right categories and tags, and publishes the fully illustrated post as a draft for review.',
    iconId: 'brand/wordpress-icon',
    modules: <String>['agent', 'files', 'workflows'],
    providerId: 'wordpress',
  ),
  SuggestionTemplate(
    id: 'workday-0',
    blockType: 'workday',
    label: 'Workday new-hire kickoff',
    prompt:
        'Build a scheduled workflow that polls Workday for newly hired employees, gathers each one’s position and start date, kicks off provisioning in downstream tools, assigns an onboarding plan, schedules introductions on Google Calendar, and notifies the team in Slack.',
    iconId: 'brand/workday-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'workday-1',
    blockType: 'workday',
    label: 'Workday pre-hire pipeline',
    prompt:
        'Create a workflow exposed as a form that captures candidate details from recruiters, validates required fields, creates a pre-hire record in Workday, returns the pre-hire identifier, and logs the submission in a recruiting tracking table.',
    iconId: 'brand/workday-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'workday-2',
    blockType: 'workday',
    label: 'Workday job change orchestrator',
    prompt:
        'Build a workflow that watches a Sim table of approved promotions, transfers, and demotions, performs the Workday change-job action for each row, updates downstream tools and Slack channel membership, and writes the outcome back to the table for audit.',
    iconId: 'brand/workday-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'workday-3',
    blockType: 'workday',
    label: 'Workday comp review prep',
    prompt:
        'Create a scheduled workflow that pulls Workday workers and their current compensation, joins with a performance ratings table, drafts manager-by-manager compensation review packets as files, and emails each manager their packet ahead of the cycle.',
    iconId: 'brand/workday-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'workday-4',
    blockType: 'workday',
    label: 'Workday termination workflow',
    prompt:
        'Build a workflow triggered by an approved offboarding request that initiates the Workday Terminate Employee business process, deactivates downstream accounts, schedules an exit interview on Google Calendar, and writes a compliance record to an audit table.',
    iconId: 'brand/workday-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'workday-5',
    blockType: 'workday',
    label: 'Workday org structure snapshot',
    prompt:
        'Create a scheduled weekly workflow that pulls Workday workers and organizations, builds an org chart file with departments and cost centers, diffs against last week to highlight structural changes, and emails the result to people leadership.',
    iconId: 'brand/workday-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'workday-6',
    blockType: 'workday',
    label: 'Workday personal-info self-service',
    prompt:
        'Build a workflow exposed as a chat or form endpoint that takes employee-submitted personal info changes, validates the request, calls the Workday Update Personal Information action, confirms back to the employee, and logs the change in a people-operations audit table.',
    iconId: 'brand/workday-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'x-0',
    blockType: 'x',
    label: 'X (Twitter) brand mention triage',
    prompt:
        'Build a scheduled workflow that polls X mentions of the brand, classifies each as praise, support request, or complaint, and routes complaints to the support team with one-tap context.',
    iconId: 'brand/x-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'x',
  ),
  SuggestionTemplate(
    id: 'x-1',
    blockType: 'x',
    label: 'X engagement digest',
    prompt:
        'Create a scheduled daily workflow that summarizes top X engagement on the brand account, identifies high-influence engagers, and writes them to a sales-prospect table.',
    iconId: 'brand/x-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'x',
  ),
  SuggestionTemplate(
    id: 'x-2',
    blockType: 'x',
    label: 'X content scheduler',
    prompt:
        'Build a workflow that reads a tables-based X content calendar and posts scheduled tweets with media at the right time, retrying transient failures.',
    iconId: 'brand/x-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'x',
  ),
  SuggestionTemplate(
    id: 'x-3',
    blockType: 'x',
    label: 'X thread expander',
    prompt:
        'Create a workflow that takes a long-form article or blog and drafts a multi-tweet X thread with hooks, key points, and a call-to-action, then queues it for review before posting.',
    iconId: 'brand/x-icon',
    modules: <String>['agent', 'files', 'workflows'],
    providerId: 'x',
  ),
  SuggestionTemplate(
    id: 'x-4',
    blockType: 'x',
    label: 'X competitor watcher',
    prompt:
        'Build a scheduled workflow that tracks tweets from competitor handles and key industry voices, captures notable posts in a table, and surfaces high-engagement items to Slack.',
    iconId: 'brand/x-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
    providerId: 'x',
  ),
  SuggestionTemplate(
    id: 'x-5',
    blockType: 'x',
    label: 'X support ticket creator',
    prompt:
        'Create a scheduled workflow that polls X for tweets directed at the brand support handle, classifies each as a support request, and opens a Zendesk ticket with the tweet context and customer profile.',
    iconId: 'brand/x-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'x',
  ),
  SuggestionTemplate(
    id: 'x-6',
    blockType: 'x',
    label: 'X bookmark research digest',
    prompt:
        'Create a scheduled weekly workflow that pulls my saved X bookmarks, fetches the full text of each bookmarked tweet, groups them by theme, writes a curated reading digest, and emails it to me before clearing the processed bookmarks.',
    iconId: 'brand/x-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
    providerId: 'x',
  ),
  SuggestionTemplate(
    id: 'youcom-0',
    blockType: 'youcom',
    label: 'You.com grounded answers',
    prompt:
        'Build an agent that takes a question from Chat, uses You.com Answer to get a cited answer from the live web, and replies with the answer plus the source links.',
    iconId: 'brand/you-com-icon',
    modules: <String>['agent', 'workflows'],
    popular: true,
  ),
  SuggestionTemplate(
    id: 'youcom-1',
    blockType: 'youcom',
    label: 'You.com research brief',
    prompt:
        'Build a workflow that takes a topic, runs You.com Research at deep effort, and saves the cited Markdown report as a file for the team.',
    iconId: 'brand/you-com-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'youcom-2',
    blockType: 'youcom',
    label: 'You.com earnings analyst',
    prompt:
        'Create a scheduled workflow that runs You.com Finance Research on each ticker in a watchlist table after earnings season, summarizes revenue drivers with citations, and writes the summary back to the table.',
    iconId: 'brand/you-com-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'youcom-3',
    blockType: 'youcom',
    label: 'You.com news monitor',
    prompt:
        'Build a scheduled daily workflow that runs You.com Search with day freshness for my competitors, extracts highlights from each news result, and posts a short digest to Slack.',
    iconId: 'brand/you-com-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'youcom-4',
    blockType: 'youcom',
    label: 'You.com knowledge loader',
    prompt:
        'Create a workflow that takes a list of documentation URLs, fetches each page as Markdown with You.com Get Contents, and adds the pages to a knowledge base so agents can answer from them.',
    iconId: 'brand/you-com-icon',
    modules: <String>['knowledge-base', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'youcom-5',
    blockType: 'youcom',
    label: 'You.com structured lead research',
    prompt:
        'Build a workflow that reads company names from a table, runs You.com Research with an output schema for headquarters, headcount, and recent funding, and writes each structured result to its row.',
    iconId: 'brand/you-com-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'youcom-6',
    blockType: 'youcom',
    label: 'You.com long-running research',
    prompt:
        'Create a workflow that starts You.com Research in the background at frontier effort, then a scheduled workflow that checks the task with Get Research Task and emails the report when it completes.',
    iconId: 'brand/you-com-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'youcom-7',
    blockType: 'youcom',
    label: 'You.com credit alert',
    prompt:
        'Build a scheduled workflow that checks the You.com account balance every morning and sends a Slack alert when remaining credits fall below a set threshold.',
    iconId: 'brand/you-com-icon',
    modules: <String>['scheduled', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'youtube-0',
    blockType: 'youtube',
    label: 'YouTube content repurposer',
    prompt:
        'Build a workflow that takes a YouTube video URL, pulls the video details and description, researches the topic on the web for additional context, and generates a Twitter thread, LinkedIn post, and blog summary optimized for each platform.',
    iconId: 'brand/you-tube-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'youtube-1',
    blockType: 'youtube',
    label: 'YouTube video audio brief',
    prompt:
        'Build a workflow that takes a YouTube URL, pulls the video details and top comments, summarizes them with an agent, narrates the summary with ElevenLabs, and saves the audio file for distribution.',
    iconId: 'brand/eleven-labs-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'youtube-2',
    blockType: 'youtube',
    label: 'YouTube channel performance digest',
    prompt:
        'Create a scheduled weekly workflow that pulls a YouTube channel’s public stats and recent videos, ranks the top performers by views, writes a digest file, and emails it to the content team.',
    iconId: 'brand/you-tube-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'youtube-3',
    blockType: 'youtube',
    label: 'YouTube comment triage',
    prompt:
        'Build a scheduled workflow that pulls recent YouTube comments on a video, classifies each as helpful, question, or spam, drafts suggested answers to questions using a knowledge base, and routes them to the community team in Slack for review.',
    iconId: 'brand/you-tube-icon',
    modules: <String>['scheduled', 'knowledge-base', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'youtube-4',
    blockType: 'youtube',
    label: 'YouTube upload-to-blog',
    prompt:
        'Create a scheduled workflow that polls a YouTube channel for new uploads, pulls each video’s details and description, generates a long-form blog post with proper SEO structure, and stages it as a WordPress draft.',
    iconId: 'brand/you-tube-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'youtube-5',
    blockType: 'youtube',
    label: 'YouTube competitor watcher',
    prompt:
        'Build a scheduled workflow that monitors competitor YouTube channels, flags videos that exceed average performance, and writes outline of their format to a content-research table.',
    iconId: 'brand/you-tube-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'youtube-6',
    blockType: 'youtube',
    label: 'YouTube video curation finder',
    prompt:
        'Create a workflow that reads a tables-based topic list, finds matching YouTube videos via search, scores each for relevance, writes the candidates back to the table, and pings the editorial team for the final cut.',
    iconId: 'brand/you-tube-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'youtube-7',
    blockType: 'youtube',
    label: 'YouTube video recap to Notion',
    prompt:
        'Build a workflow that takes a YouTube video URL, pulls the video details, description, and top comments, summarizes the highlights and audience reaction, and saves a recap to a Notion page for the marketing team.',
    iconId: 'brand/you-tube-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'zendesk-0',
    blockType: 'zendesk',
    label: 'Zendesk ticket knowledge search',
    prompt:
        'Create a knowledge base connected to my Zendesk account so all past tickets, resolutions, and agent notes are automatically synced and searchable. Then build an agent my support team can ask things like "how do we usually resolve the SSO login issue?" or "has anyone reported this billing bug before?" to find past solutions instantly.',
    iconId: 'brand/zendesk-icon',
    modules: <String>['knowledge-base', 'agent'],
  ),
  SuggestionTemplate(
    id: 'zendesk-1',
    blockType: 'zendesk',
    label: 'Zendesk auto-classifier',
    prompt:
        'Build a scheduled workflow that polls Zendesk for new tickets, classifies each one by product area, severity, and intent, applies the matching tags, sets priority, and assigns it to the right group so triage happens automatically.',
    iconId: 'brand/zendesk-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'zendesk-2',
    blockType: 'zendesk',
    label: 'Zendesk SLA breach alert',
    prompt:
        'Create a scheduled workflow that searches Zendesk every 15 minutes for tickets at risk of breaching first-response or resolution SLA, summarizes each one, and posts a Slack alert to the responsible group with deep links to the tickets.',
    iconId: 'brand/zendesk-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'zendesk-3',
    blockType: 'zendesk',
    label: 'Zendesk ticket deflector',
    prompt:
        'Create a knowledge base from help center articles and past ticket resolutions, then build a scheduled workflow that polls for new Zendesk tickets, drafts a public reply using the knowledge base with citations, and posts it as an internal note for agents to send with one click.',
    iconId: 'brand/zendesk-icon',
    modules: <String>['scheduled', 'knowledge-base', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'zendesk-4',
    blockType: 'zendesk',
    label: 'Zendesk to Jira engineering bridge',
    prompt:
        'Build a scheduled workflow that searches Zendesk for tickets newly tagged as a bug, creates a linked Jira issue with the ticket details and customer impact, and posts the Jira link back as an internal note on the Zendesk ticket.',
    iconId: 'brand/zendesk-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'zendesk-5',
    blockType: 'zendesk',
    label: 'Zendesk weekly CX pulse',
    prompt:
        'Create a scheduled weekly workflow that pulls Zendesk ticket volume, CSAT, top tags, and recurring issues, generates a narrative CX pulse with week-over-week deltas, and posts it to Slack with links to the standout tickets.',
    iconId: 'brand/zendesk-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'zendesk-6',
    blockType: 'zendesk',
    label: 'Zendesk customer record sync',
    prompt:
        'Build a workflow that watches my CRM for new or updated accounts, searches Zendesk for the matching user and organization, and creates or updates them in bulk so support agents always see the latest company, plan, and contact details on every ticket.',
    iconId: 'brand/zendesk-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'zep-0',
    blockType: 'zep',
    label: 'Zep session memory for chat',
    prompt:
        'Create a chat agent that stores every turn in Zep with user metadata, retrieves the most relevant prior context on each new question, and answers with continuity instead of forgetting.',
    iconId: 'brand/zep-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'zep-1',
    blockType: 'zep',
    label: 'Zep + knowledge base support bot',
    prompt:
        'Build a support agent that combines Zep session memory with a knowledge base, so it remembers what the customer has already tried while still grounding answers in product docs.',
    iconId: 'brand/zep-icon',
    modules: <String>['knowledge-base', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'zep-2',
    blockType: 'zep',
    label: 'Zep + Salesforce account memory',
    prompt:
        'Build a workflow that for each Salesforce account writes meeting and email context into Zep keyed by account, so any future agent interaction has full history.',
    iconId: 'brand/zep-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'zep-3',
    blockType: 'zep',
    label: 'Zep + Intercom support continuity',
    prompt:
        'Create a Zep-backed support agent for Intercom that remembers what each customer has tried before, prefers, or escalated, so support conversations never restart from scratch.',
    iconId: 'brand/zep-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'zep-4',
    blockType: 'zep',
    label: 'Zep evaluation harness',
    prompt:
        'Build a scheduled workflow that evaluates Zep memory recall accuracy weekly against a labeled eval set, captures regressions, and writes a quality report.',
    iconId: 'brand/zep-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'zep-5',
    blockType: 'zep',
    label: 'Zep personal-assistant memory',
    prompt:
        'Create a personal assistant agent that records preferences, recurring tasks, and prior decisions in Zep, then retrieves the relevant facts on each request so it stays consistent across days instead of asking the same questions again.',
    iconId: 'brand/zep-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'zep-6',
    blockType: 'zep',
    label: 'Zep + Slack team-context bot',
    prompt:
        'Build a Slack bot that stores each conversation in Zep keyed by channel and user, retrieves the relevant prior context when someone asks a follow-up, and answers in thread with continuity across the whole team’s history.',
    iconId: 'brand/zep-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'zoho_desk-0',
    blockType: 'zoho_desk',
    label: 'Zoho Desk new-ticket Slack alert',
    prompt:
        'When a new ticket is created in Zoho Desk, send a formatted Slack message to my support channel with the subject, priority, requester, and a link to the ticket.',
    iconId: 'brand/zoho-desk-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'zoho-desk',
  ),
  SuggestionTemplate(
    id: 'zoho_desk-1',
    blockType: 'zoho_desk',
    label: 'Zoho Desk AI ticket triage',
    prompt:
        'When a Zoho Desk ticket is created, read the subject and description, classify the priority and category, and update the ticket with the suggested priority and a triage comment.',
    iconId: 'brand/zoho-desk-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'zoho-desk',
  ),
  SuggestionTemplate(
    id: 'zoho_desk-2',
    blockType: 'zoho_desk',
    label: 'Zoho Desk AI draft reply',
    prompt:
        'When a customer adds a new thread to a Zoho Desk ticket, fetch the full thread, draft a helpful reply grounded in my knowledge base, and post it as a private comment for an agent to review.',
    iconId: 'brand/zoho-desk-icon',
    modules: <String>['agent', 'knowledge-base', 'workflows'],
    providerId: 'zoho-desk',
  ),
  SuggestionTemplate(
    id: 'zoho_desk-3',
    blockType: 'zoho_desk',
    label: 'Zoho Desk escalation watcher',
    prompt:
        'Create a scheduled workflow that lists open high-priority Zoho Desk tickets with no agent response, and pings the on-call engineer in Slack with the ticket details.',
    iconId: 'brand/zoho-desk-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'zoho-desk',
  ),
  SuggestionTemplate(
    id: 'zoho_desk-4',
    blockType: 'zoho_desk',
    label: 'Zoho Desk daily support digest',
    prompt:
        'Build a scheduled workflow that searches Zoho Desk tickets using modifiedTimeRange for the last 24 hours, summarizes volume by status and priority, and emails a digest to the support lead.',
    iconId: 'brand/zoho-desk-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'zoho-desk',
  ),
  SuggestionTemplate(
    id: 'zoho_desk-5',
    blockType: 'zoho_desk',
    label: 'Zoho Desk contact enrichment',
    prompt:
        'When a Zoho Desk ticket is created, look up the contact, enrich it with data from our CRM, and add a comment summarizing the customer context for the agent.',
    iconId: 'brand/zoho-desk-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'zoho-desk',
  ),
  SuggestionTemplate(
    id: 'zoho_desk-6',
    blockType: 'zoho_desk',
    label: 'Zoho Desk knowledge search',
    prompt:
        'Create a knowledge base from my resolved Zoho Desk tickets and threads so I can ask an agent questions like "how did we resolve the billing sync issue?" and get answers with ticket citations.',
    iconId: 'brand/zoho-desk-icon',
    modules: <String>['knowledge-base', 'agent'],
    providerId: 'zoho-desk',
  ),
  SuggestionTemplate(
    id: 'zoho_desk-7',
    blockType: 'zoho_desk',
    label: 'Zoho Desk attachment archiver',
    prompt:
        'When a Zoho Desk ticket thread includes an attachment, download the file and upload it to Google Drive in a folder named after the ticket number.',
    iconId: 'brand/zoho-desk-icon',
    modules: <String>['agent', 'files', 'workflows'],
    providerId: 'zoho-desk',
  ),
  SuggestionTemplate(
    id: 'zoom-0',
    blockType: 'zoom',
    label: 'Zoom recording recap',
    prompt:
        'Build a workflow that runs after a Zoom meeting ends, pulls the cloud recording transcript, summarizes decisions and action items, and posts the recap to the linked Slack channel.',
    iconId: 'brand/zoom-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'zoom',
  ),
  SuggestionTemplate(
    id: 'zoom-1',
    blockType: 'zoom',
    label: 'Zoom meeting prep brief',
    prompt:
        'Create a scheduled workflow that runs each morning, lists today’s Zoom meetings, researches attendees with Apollo and the web, and emails a prep brief 30 minutes before each meeting.',
    iconId: 'brand/zoom-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
    providerId: 'zoom',
  ),
  SuggestionTemplate(
    id: 'zoom-2',
    blockType: 'zoom',
    label: 'Zoom webinar follow-up',
    prompt:
        'Build a workflow that runs after a Zoom webinar, pulls the registrant and attendee lists, sends a follow-up email with the recording link, and writes attendance into HubSpot for marketing scoring.',
    iconId: 'brand/zoom-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'zoom',
  ),
  SuggestionTemplate(
    id: 'zoom-3',
    blockType: 'zoom',
    label: 'Zoom + Notion meeting notes',
    prompt:
        'Create a workflow that watches for Zoom recordings, transcribes, and writes a structured meeting-notes page to Notion under the right team space, with action items linked to owners.',
    iconId: 'brand/zoom-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'zoom',
  ),
  SuggestionTemplate(
    id: 'zoom-4',
    blockType: 'zoom',
    label: 'Zoom sales-call deal updater',
    prompt:
        'Build a workflow that runs after a Zoom sales call, summarizes objections, next steps, and stage signals from the transcript, and updates the linked Salesforce or HubSpot opportunity.',
    iconId: 'brand/zoom-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'zoom',
  ),
  SuggestionTemplate(
    id: 'zoom-5',
    blockType: 'zoom',
    label: 'Zoom recurring 1:1 logger',
    prompt:
        'Create a workflow that captures Zoom 1:1 meeting recaps, appends them to a per-employee log file, and surfaces talking points for the next 1:1 to the manager in Slack.',
    iconId: 'brand/zoom-icon',
    modules: <String>['agent', 'files', 'workflows'],
    providerId: 'zoom',
  ),
  SuggestionTemplate(
    id: 'zoom-6',
    blockType: 'zoom',
    label: 'Zoom + Telegram recap pusher',
    prompt:
        'Create a workflow that runs after a Zoom meeting, summarizes the transcript, and pushes the recap to a chosen Telegram channel for asynchronous review.',
    iconId: 'brand/zoom-icon',
    modules: <String>['agent', 'workflows'],
    providerId: 'zoom',
  ),
  SuggestionTemplate(
    id: 'zoominfo-0',
    blockType: 'zoominfo',
    label: 'ZoomInfo contact enricher',
    prompt:
        'Build a workflow that watches CRM contacts, enriches each via ZoomInfo with title, seniority, and verified contact details, and writes the enriched data back.',
    iconId: 'brand/zoom-info-icon',
    modules: <String>['agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'zoominfo-1',
    blockType: 'zoominfo',
    label: 'ZoomInfo account builder',
    prompt:
        'Create a workflow that runs a ZoomInfo company search against my ICP filters, enriches each match with firmographics, and writes the target account list into a tables-based research base.',
    iconId: 'brand/zoom-info-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'zoominfo-2',
    blockType: 'zoominfo',
    label: 'ZoomInfo intent monitor',
    prompt:
        'Build a scheduled workflow that pulls ZoomInfo intent signals for tracked accounts, ranks accounts surging on relevant topics, and posts a daily Slack alert for the sales team.',
    iconId: 'brand/zoom-info-icon',
    modules: <String>['scheduled', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'zoominfo-3',
    blockType: 'zoominfo',
    label: 'ZoomInfo news digest',
    prompt:
        'Create a scheduled weekly workflow that searches ZoomInfo news for tracked accounts, summarizes notable events with an agent, and writes a per-account briefing for the sales team.',
    iconId: 'brand/zoom-info-icon',
    modules: <String>['scheduled', 'agent', 'files', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'zoominfo-4',
    blockType: 'zoominfo',
    label: 'ZoomInfo CRM gap-filler',
    prompt:
        'Build a scheduled workflow that finds Salesforce contacts missing firmographic or contact fields, runs ZoomInfo enrichment to fill the gaps, and writes coverage metrics to a hygiene table.',
    iconId: 'brand/zoom-info-icon',
    modules: <String>['scheduled', 'tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'zoominfo-5',
    blockType: 'zoominfo',
    label: 'ZoomInfo buying-committee builder',
    prompt:
        'Build a workflow that takes a target account, runs a ZoomInfo contact search to find the decision-makers by title and department, enriches each with verified email and phone, and writes the mapped buying committee into a sales table for outreach.',
    iconId: 'brand/zoom-info-icon',
    modules: <String>['tables', 'agent', 'workflows'],
  ),
  SuggestionTemplate(
    id: 'zoominfo-6',
    blockType: 'zoominfo',
    label: 'ZoomInfo account briefing pack',
    prompt:
        'Create a workflow that takes an upcoming meeting account, pulls ZoomInfo company firmographics, recent intent signals, and the latest news for that company, and assembles a one-page pre-meeting briefing document the rep reads before the call.',
    iconId: 'brand/zoom-info-icon',
    modules: <String>['agent', 'files', 'workflows'],
  ),
];

/// `OAUTH_PROVIDERS` services: (service key, name, providerId).
const List<OAuthServiceEntry> oauthServiceCatalog = <OAuthServiceEntry>[
  OAuthServiceEntry(
    id: 'greenhouse',
    name: 'Greenhouse',
    providerId: 'greenhouse',
  ),
  OAuthServiceEntry(
    id: 'github-repositories',
    name: 'GitHub',
    providerId: 'github-repositories',
  ),
  OAuthServiceEntry(
    id: 'claude-platform',
    name: 'Claude Platform',
    providerId: 'claude-platform',
  ),
  OAuthServiceEntry(id: 'gmail', name: 'Gmail', providerId: 'google-email'),
  OAuthServiceEntry(
    id: 'google-drive',
    name: 'Google Drive',
    providerId: 'google-drive',
  ),
  OAuthServiceEntry(
    id: 'google-docs',
    name: 'Google Docs',
    providerId: 'google-docs',
  ),
  OAuthServiceEntry(
    id: 'google-sheets',
    name: 'Google Sheets',
    providerId: 'google-sheets',
  ),
  OAuthServiceEntry(
    id: 'google-forms',
    name: 'Google Forms',
    providerId: 'google-forms',
  ),
  OAuthServiceEntry(
    id: 'google-calendar',
    name: 'Google Calendar',
    providerId: 'google-calendar',
  ),
  OAuthServiceEntry(
    id: 'google-contacts',
    name: 'Google Contacts',
    providerId: 'google-contacts',
  ),
  OAuthServiceEntry(
    id: 'google-ads',
    name: 'Google Ads',
    providerId: 'google-ads',
  ),
  OAuthServiceEntry(
    id: 'google-bigquery',
    name: 'Google BigQuery',
    providerId: 'google-bigquery',
  ),
  OAuthServiceEntry(
    id: 'google-tasks',
    name: 'Google Tasks',
    providerId: 'google-tasks',
  ),
  OAuthServiceEntry(
    id: 'google-vault',
    name: 'Google Vault',
    providerId: 'google-vault',
  ),
  OAuthServiceEntry(
    id: 'google-groups',
    name: 'Google Groups',
    providerId: 'google-groups',
  ),
  OAuthServiceEntry(
    id: 'google-chat',
    name: 'Google Chat',
    providerId: 'google-chat',
  ),
  OAuthServiceEntry(
    id: 'google-meet',
    name: 'Google Meet',
    providerId: 'google-meet',
  ),
  OAuthServiceEntry(
    id: 'google-service-account',
    name: 'Google Service Account',
    providerId: 'google-service-account',
  ),
  OAuthServiceEntry(
    id: 'vertex-ai',
    name: 'Vertex AI',
    providerId: 'vertex-ai',
  ),
  OAuthServiceEntry(
    id: 'microsoft-ad',
    name: 'Azure AD',
    providerId: 'microsoft-ad',
  ),
  OAuthServiceEntry(
    id: 'microsoft-dataverse',
    name: 'Microsoft Dataverse',
    providerId: 'microsoft-dataverse',
  ),
  OAuthServiceEntry(
    id: 'microsoft-excel',
    name: 'Microsoft Excel',
    providerId: 'microsoft-excel',
  ),
  OAuthServiceEntry(
    id: 'microsoft-intune',
    name: 'Microsoft Intune',
    providerId: 'microsoft-intune',
  ),
  OAuthServiceEntry(
    id: 'microsoft-planner',
    name: 'Microsoft Planner',
    providerId: 'microsoft-planner',
  ),
  OAuthServiceEntry(
    id: 'microsoft-powerbi',
    name: 'Power BI',
    providerId: 'microsoft-powerbi',
  ),
  OAuthServiceEntry(
    id: 'microsoft-teams',
    name: 'Microsoft Teams',
    providerId: 'microsoft-teams',
  ),
  OAuthServiceEntry(
    id: 'microsoft-word',
    name: 'Microsoft Word',
    providerId: 'microsoft-word',
  ),
  OAuthServiceEntry(id: 'outlook', name: 'Outlook', providerId: 'outlook'),
  OAuthServiceEntry(id: 'onedrive', name: 'OneDrive', providerId: 'onedrive'),
  OAuthServiceEntry(
    id: 'sharepoint',
    name: 'SharePoint',
    providerId: 'sharepoint',
  ),
  OAuthServiceEntry(id: 'x', name: 'X', providerId: 'x'),
  OAuthServiceEntry(id: 'tiktok', name: 'TikTok', providerId: 'tiktok'),
  OAuthServiceEntry(
    id: 'atlassian-service-account',
    name: 'Atlassian Service Account',
    providerId: 'atlassian-service-account',
  ),
  OAuthServiceEntry(
    id: 'confluence',
    name: 'Confluence',
    providerId: 'confluence',
  ),
  OAuthServiceEntry(id: 'jira', name: 'Jira', providerId: 'jira'),
  OAuthServiceEntry(id: 'airtable', name: 'Airtable', providerId: 'airtable'),
  OAuthServiceEntry(
    id: 'bitbucket',
    name: 'Bitbucket',
    providerId: 'bitbucket',
  ),
  OAuthServiceEntry(id: 'notion', name: 'Notion', providerId: 'notion'),
  OAuthServiceEntry(id: 'clickup', name: 'ClickUp', providerId: 'clickup'),
  OAuthServiceEntry(id: 'linear', name: 'Linear', providerId: 'linear'),
  OAuthServiceEntry(
    id: 'manageengine-sdp',
    name: 'ManageEngine ServiceDesk Plus',
    providerId: 'manageengine-sdp',
  ),
  OAuthServiceEntry(id: 'monday', name: 'Monday.com', providerId: 'monday'),
  OAuthServiceEntry(id: 'box', name: 'Box', providerId: 'box'),
  OAuthServiceEntry(id: 'dropbox', name: 'Dropbox', providerId: 'dropbox'),
  OAuthServiceEntry(id: 'shopify', name: 'Shopify', providerId: 'shopify'),
  OAuthServiceEntry(id: 'slack', name: 'Slack', providerId: 'slack'),
  OAuthServiceEntry(
    id: 'snowflake',
    name: 'Snowflake',
    providerId: 'snowflake',
  ),
  OAuthServiceEntry(
    id: 'netsuite',
    name: 'Oracle NetSuite',
    providerId: 'netsuite',
  ),
  OAuthServiceEntry(
    id: 'oracledb',
    name: 'Oracle Database',
    providerId: 'oracledb',
  ),
  OAuthServiceEntry(
    id: 'oci',
    name: 'Oracle Cloud Infrastructure',
    providerId: 'oci',
  ),
  OAuthServiceEntry(
    id: 'oracle-epm',
    name: 'Oracle EPM',
    providerId: 'oracle-epm',
  ),
  OAuthServiceEntry(
    id: 'oracle-fusion',
    name: 'Oracle Fusion',
    providerId: 'oracle-fusion',
  ),
  OAuthServiceEntry(id: 'reddit', name: 'Reddit', providerId: 'reddit'),
  OAuthServiceEntry(
    id: 'wealthbox',
    name: 'Wealthbox',
    providerId: 'wealthbox',
  ),
  OAuthServiceEntry(id: 'webflow', name: 'Webflow', providerId: 'webflow'),
  OAuthServiceEntry(id: 'trello', name: 'Trello', providerId: 'trello'),
  OAuthServiceEntry(id: 'asana', name: 'Asana', providerId: 'asana'),
  OAuthServiceEntry(id: 'attio', name: 'Attio', providerId: 'attio'),
  OAuthServiceEntry(id: 'calcom', name: 'Cal.com', providerId: 'calcom'),
  OAuthServiceEntry(id: 'docusign', name: 'DocuSign', providerId: 'docusign'),
  OAuthServiceEntry(
    id: 'pipedrive',
    name: 'Pipedrive',
    providerId: 'pipedrive',
  ),
  OAuthServiceEntry(
    id: 'quickbooks',
    name: 'QuickBooks',
    providerId: 'quickbooks',
  ),
  OAuthServiceEntry(id: 'ramp', name: 'Ramp', providerId: 'ramp'),
  OAuthServiceEntry(id: 'fivetran', name: 'Fivetran', providerId: 'fivetran'),
  OAuthServiceEntry(id: 'vanta', name: 'Vanta', providerId: 'vanta'),
  OAuthServiceEntry(
    id: 'helpscout',
    name: 'Help Scout',
    providerId: 'helpscout',
  ),
  OAuthServiceEntry(id: 'hubspot', name: 'HubSpot', providerId: 'hubspot'),
  OAuthServiceEntry(id: 'coda', name: 'Coda', providerId: 'coda'),
  OAuthServiceEntry(id: 'harmonic', name: 'Harmonic', providerId: 'harmonic'),
  OAuthServiceEntry(id: 'linkedin', name: 'LinkedIn', providerId: 'linkedin'),
  OAuthServiceEntry(
    id: 'instagram',
    name: 'Instagram',
    providerId: 'instagram',
  ),
  OAuthServiceEntry(
    id: 'salesforce',
    name: 'Salesforce',
    providerId: 'salesforce',
  ),
  OAuthServiceEntry(
    id: 'zoho-desk',
    name: 'Zoho Desk',
    providerId: 'zoho-desk',
  ),
  OAuthServiceEntry(id: 'zoom', name: 'Zoom', providerId: 'zoom'),
  OAuthServiceEntry(
    id: 'wordpress',
    name: 'WordPress',
    providerId: 'wordpress',
  ),
  OAuthServiceEntry(id: 'spotify', name: 'Spotify', providerId: 'spotify'),
];

/// `SLUG_BY_LOWER_NAME` (`suggested-actions.tsx:31-33`).
const Map<String, String> integrationSlugByLowerName = <String, String>{
  '1password': '1password',
  'affinity': 'affinity',
  'agentmail': 'agentmail',
  'agentphone': 'agentphone',
  'agiloft': 'agiloft',
  'ahrefs': 'ahrefs',
  'airtable': 'airtable',
  'algolia': 'algolia',
  'amazon dynamodb': 'amazon-dynamodb',
  'amazon rds': 'amazon-rds',
  'amazon sqs': 'amazon-sqs',
  'amplitude': 'amplitude',
  'apify': 'apify',
  'apollo': 'apollo',
  'arxiv': 'arxiv',
  'asana': 'asana',
  'ashby': 'ashby',
  'athena': 'athena',
  'attio': 'attio',
  'aws appconfig': 'aws-appconfig',
  'aws iam': 'aws-iam',
  'aws identity center': 'aws-identity-center',
  'aws secrets manager': 'aws-secrets-manager',
  'aws ses': 'aws-ses',
  'aws sts': 'aws-sts',
  'aws systems manager': 'aws-systems-manager',
  'aws textract': 'aws-textract',
  'azure ad': 'azure-ad',
  'azure data explorer': 'azure-data-explorer',
  'azure devops': 'azure-devops',
  'bitbucket': 'bitbucket',
  'box': 'box',
  'brandfetch': 'brandfetch',
  'brex': 'brex',
  'bright data': 'bright-data',
  'browser use': 'browser-use',
  'buffer': 'buffer',
  'cal.com': 'cal-com',
  'calendly': 'calendly',
  'cb insights': 'cb-insights',
  'checkr': 'checkr',
  'circleback': 'circleback',
  'claude managed agents': 'claude-managed-agents',
  'clay': 'clay',
  'clerk': 'clerk',
  'clickhouse': 'clickhouse',
  'clickup': 'clickup',
  'cloudflare': 'cloudflare',
  'cloudformation': 'cloudformation',
  'cloudtrail': 'cloudtrail',
  'cloudwatch': 'cloudwatch',
  'coda': 'coda',
  'codepipeline': 'codepipeline',
  'confluence': 'confluence',
  'context.dev': 'context-dev',
  'convex': 'convex',
  'crowdstrike': 'crowdstrike',
  'crunchbase': 'crunchbase',
  'cursor': 'cursor',
  'dagster': 'dagster',
  'databricks': 'databricks',
  'datadog': 'datadog',
  'datagma': 'datagma',
  'daytona': 'daytona',
  'devin': 'devin',
  'discord': 'discord',
  'docusign': 'docusign',
  'downdetector': 'downdetector',
  'dropbox': 'dropbox',
  'dropcontact': 'dropcontact',
  'dspy': 'dspy',
  'dub': 'dub',
  'duckduckgo': 'duckduckgo',
  'dynatrace': 'dynatrace',
  'elasticsearch': 'elasticsearch',
  'elevenlabs': 'elevenlabs',
  'email bison': 'email-bison',
  'embeddings': 'embeddings',
  'enrich': 'enrich',
  'enrow': 'enrow',
  'exa': 'exa',
  'extend': 'extend',
  'fathom': 'fathom',
  'findymail': 'findymail',
  'firecrawl': 'firecrawl',
  'fireflies': 'fireflies',
  'fivetran': 'fivetran',
  'flint': 'flint',
  'gamma': 'gamma',
  'github': 'github',
  'gitlab': 'gitlab',
  'gmail': 'gmail',
  'gong': 'gong',
  'google ads': 'google-ads',
  'google appsheet': 'google-appsheet',
  'google bigquery': 'google-bigquery',
  'google books': 'google-books',
  'google calendar': 'google-calendar',
  'google contacts': 'google-contacts',
  'google docs': 'google-docs',
  'google drive': 'google-drive',
  'google forms': 'google-forms',
  'google groups': 'google-groups',
  'google maps': 'google-maps',
  'google meet': 'google-meet',
  'google pagespeed': 'google-pagespeed',
  'google search': 'google-search',
  'google sheets': 'google-sheets',
  'google slides': 'google-slides',
  'google tasks': 'google-tasks',
  'google translate': 'google-translate',
  'google vault': 'google-vault',
  'grafana': 'grafana',
  'grain': 'grain',
  'granola': 'granola',
  'greenhouse': 'greenhouse',
  'greptile': 'greptile',
  'harmonic': 'harmonic',
  'help scout': 'help-scout',
  'hex': 'hex',
  'hubspot': 'hubspot',
  'hugging face': 'hugging-face',
  'hunter.io': 'hunter-io',
  'icypeas': 'icypeas',
  'incident.io': 'incident-io',
  'infisical': 'infisical',
  'instantly': 'instantly',
  'intercom': 'intercom',
  'jina': 'jina',
  'jira': 'jira',
  'jira service management': 'jira-service-management',
  'jotform': 'jotform',
  'jupyter': 'jupyter',
  'kalshi': 'kalshi',
  'ketch': 'ketch',
  'lambda': 'lambda',
  'langsmith': 'langsmith',
  'latex': 'latex',
  'launchdarkly': 'launchdarkly',
  'leadmagic': 'leadmagic',
  'lemlist': 'lemlist',
  'linear': 'linear',
  'linkedin': 'linkedin',
  'linkup': 'linkup',
  'linq': 'linq',
  'logfire': 'logfire',
  'logrocket': 'logrocket',
  'loops': 'loops',
  'luma': 'luma',
  'mailchimp': 'mailchimp',
  'mailgun': 'mailgun',
  'manageengine servicedesk plus': 'manageengine-servicedesk-plus',
  'mem0': 'mem0',
  'microsoft dataverse': 'microsoft-dataverse',
  'microsoft dynamics 365 crm': 'microsoft-dynamics-365-crm',
  'microsoft excel': 'microsoft-excel',
  'microsoft intune': 'microsoft-intune',
  'microsoft planner': 'microsoft-planner',
  'microsoft sql server': 'microsoft-sql-server',
  'microsoft teams': 'microsoft-teams',
  'microsoft word': 'microsoft-word',
  'millionverifier': 'millionverifier',
  'mintlify': 'mintlify',
  'mistral parser': 'mistral-parser',
  'modal': 'modal',
  'monday': 'monday',
  'mongodb': 'mongodb',
  'mysql': 'mysql',
  'neo4j': 'neo4j',
  'neverbounce': 'neverbounce',
  'new relic': 'new-relic',
  'notion': 'notion',
  'obsidian': 'obsidian',
  'okta': 'okta',
  'onedrive': 'onedrive',
  'oracle database': 'oracle-database',
  'oracle fusion financials': 'oracle-fusion-financials',
  'oracle netsuite': 'oracle-netsuite',
  'otter.ai': 'otter-ai',
  'outlook': 'outlook',
  'pagerduty': 'pagerduty',
  'parallel ai': 'parallel-ai',
  'people data labs': 'people-data-labs',
  'perplexity': 'perplexity',
  'persona': 'persona',
  'pinecone': 'pinecone',
  'pipedrive': 'pipedrive',
  'pitchbook': 'pitchbook',
  'plane': 'plane',
  'planetscale': 'planetscale',
  'polymarket': 'polymarket',
  'postgresql': 'postgresql',
  'posthog': 'posthog',
  'power bi': 'power-bi',
  'profound': 'profound',
  'prospeo': 'prospeo',
  'pulse': 'pulse',
  'qdrant': 'qdrant',
  'quartr': 'quartr',
  'quickbooks': 'quickbooks',
  'quiver': 'quiver',
  'rabbitmq': 'rabbitmq',
  'railway': 'railway',
  'ramp': 'ramp',
  'rb2b': 'rb2b',
  'reddit': 'reddit',
  'redis': 'redis',
  'reducto': 'reducto',
  'resend': 'resend',
  'revenuecat': 'revenuecat',
  'rippling': 'rippling',
  'rocketlane': 'rocketlane',
  'rootly': 'rootly',
  's3': 's3',
  'sailpoint': 'sailpoint',
  'salesforce': 'salesforce',
  'sap concur': 'sap-concur',
  'sap s4hana': 'sap-s4hana',
  'semrush': 'semrush',
  'sendblue': 'sendblue',
  'sendgrid': 'sendgrid',
  'sentry': 'sentry',
  'serper': 'serper',
  'servicenow': 'servicenow',
  'sftp': 'sftp',
  'sharepoint': 'sharepoint',
  'shopify': 'shopify',
  'similarweb': 'similarweb',
  'sixtyfour ai': 'sixtyfour-ai',
  'slack': 'slack',
  'smartlead': 'smartlead',
  'smtp': 'smtp',
  'snowflake': 'snowflake',
  'splunk': 'splunk',
  'sportmonks': 'sportmonks',
  'square': 'square',
  'ssh': 'ssh',
  'stagehand': 'stagehand',
  'stripe': 'stripe',
  'supabase': 'supabase',
  'tailscale': 'tailscale',
  'tavily': 'tavily',
  'telegram': 'telegram',
  'temporal': 'temporal',
  'thrive': 'thrive',
  'tiktok': 'tiktok',
  'tinybird': 'tinybird',
  'tinyfish': 'tinyfish',
  'trello': 'trello',
  'trigger.dev': 'trigger-dev',
  'twilio sms': 'twilio-sms',
  'twilio voice': 'twilio-voice',
  'typeform': 'typeform',
  'upstash': 'upstash',
  'uptimerobot': 'uptimerobot',
  'vanta': 'vanta',
  'vercel': 'vercel',
  'wealthbox': 'wealthbox',
  'webflow': 'webflow',
  'whatsapp': 'whatsapp',
  'wikipedia': 'wikipedia',
  'windchill': 'windchill',
  'wiza': 'wiza',
  'wordpress': 'wordpress',
  'workday': 'workday',
  'x': 'x',
  'you.com': 'you-com',
  'youtube': 'youtube',
  'zendesk': 'zendesk',
  'zep': 'zep',
  'zerobounce': 'zerobounce',
  'zoho desk': 'zoho-desk',
  'zoom': 'zoom',
  'zoominfo': 'zoominfo',
};

/// `TYPE_BY_SLUG` (`suggested-actions.tsx:36-38`).
const Map<String, String> integrationTypeBySlug = <String, String>{
  '1password': 'onepassword',
  'affinity': 'affinity',
  'agentmail': 'agentmail',
  'agentphone': 'agentphone',
  'agiloft': 'agiloft',
  'ahrefs': 'ahrefs',
  'airtable': 'airtable',
  'algolia': 'algolia',
  'amazon-dynamodb': 'dynamodb',
  'amazon-rds': 'rds',
  'amazon-sqs': 'sqs',
  'amplitude': 'amplitude',
  'apify': 'apify',
  'apollo': 'apollo',
  'arxiv': 'arxiv',
  'asana': 'asana',
  'ashby': 'ashby',
  'athena': 'athena',
  'attio': 'attio',
  'aws-appconfig': 'appconfig',
  'aws-iam': 'iam',
  'aws-identity-center': 'identity_center',
  'aws-secrets-manager': 'secrets_manager',
  'aws-ses': 'ses',
  'aws-sts': 'sts',
  'aws-systems-manager': 'ssm',
  'aws-textract': 'textract',
  'azure-ad': 'microsoft_ad',
  'azure-data-explorer': 'azure_data_explorer',
  'azure-devops': 'azure_devops',
  'bitbucket': 'bitbucket',
  'box': 'box',
  'brandfetch': 'brandfetch',
  'brex': 'brex',
  'bright-data': 'brightdata',
  'browser-use': 'browser_use',
  'buffer': 'buffer',
  'cal-com': 'calcom',
  'calendly': 'calendly',
  'cb-insights': 'cbinsights',
  'checkr': 'checkr',
  'circleback': 'circleback',
  'claude-managed-agents': 'managed_agent',
  'clay': 'clay',
  'clerk': 'clerk',
  'clickhouse': 'clickhouse',
  'clickup': 'clickup',
  'cloudflare': 'cloudflare',
  'cloudformation': 'cloudformation',
  'cloudtrail': 'cloudtrail',
  'cloudwatch': 'cloudwatch',
  'coda': 'coda',
  'codepipeline': 'codepipeline',
  'confluence': 'confluence',
  'context-dev': 'context_dev',
  'convex': 'convex',
  'crowdstrike': 'crowdstrike',
  'crunchbase': 'crunchbase',
  'cursor': 'cursor',
  'dagster': 'dagster',
  'databricks': 'databricks',
  'datadog': 'datadog',
  'datagma': 'datagma',
  'daytona': 'daytona',
  'devin': 'devin',
  'discord': 'discord',
  'docusign': 'docusign',
  'downdetector': 'downdetector',
  'dropbox': 'dropbox',
  'dropcontact': 'dropcontact',
  'dspy': 'dspy',
  'dub': 'dub',
  'duckduckgo': 'duckduckgo',
  'dynatrace': 'dynatrace',
  'elasticsearch': 'elasticsearch',
  'elevenlabs': 'elevenlabs',
  'email-bison': 'emailbison',
  'embeddings': 'embeddings',
  'enrich': 'enrich',
  'enrow': 'enrow',
  'exa': 'exa',
  'extend': 'extend',
  'fathom': 'fathom',
  'findymail': 'findymail',
  'firecrawl': 'firecrawl',
  'fireflies': 'fireflies',
  'fivetran': 'fivetran',
  'flint': 'flint',
  'gamma': 'gamma',
  'github': 'github',
  'gitlab': 'gitlab',
  'gmail': 'gmail',
  'gong': 'gong',
  'google-ads': 'google_ads',
  'google-appsheet': 'google_appsheet',
  'google-bigquery': 'google_bigquery',
  'google-books': 'google_books',
  'google-calendar': 'google_calendar',
  'google-contacts': 'google_contacts',
  'google-docs': 'google_docs',
  'google-drive': 'google_drive',
  'google-forms': 'google_forms',
  'google-groups': 'google_groups',
  'google-maps': 'google_maps',
  'google-meet': 'google_meet',
  'google-pagespeed': 'google_pagespeed',
  'google-search': 'google_search',
  'google-sheets': 'google_sheets',
  'google-slides': 'google_slides',
  'google-tasks': 'google_tasks',
  'google-translate': 'google_translate',
  'google-vault': 'google_vault',
  'grafana': 'grafana',
  'grain': 'grain',
  'granola': 'granola',
  'greenhouse': 'greenhouse',
  'greptile': 'greptile',
  'harmonic': 'harmonic',
  'help-scout': 'helpscout',
  'hex': 'hex',
  'hubspot': 'hubspot',
  'hugging-face': 'huggingface',
  'hunter-io': 'hunter',
  'icypeas': 'icypeas',
  'incident-io': 'incidentio',
  'infisical': 'infisical',
  'instantly': 'instantly',
  'intercom': 'intercom',
  'jina': 'jina',
  'jira': 'jira',
  'jira-service-management': 'jira_service_management',
  'jotform': 'jotform',
  'jupyter': 'jupyter',
  'kalshi': 'kalshi',
  'ketch': 'ketch',
  'lambda': 'lambda',
  'langsmith': 'langsmith',
  'latex': 'latex',
  'launchdarkly': 'launchdarkly',
  'leadmagic': 'leadmagic',
  'lemlist': 'lemlist',
  'linear': 'linear',
  'linkedin': 'linkedin',
  'linkup': 'linkup',
  'linq': 'linq',
  'logfire': 'logfire',
  'logrocket': 'logrocket',
  'loops': 'loops',
  'luma': 'luma',
  'mailchimp': 'mailchimp',
  'mailgun': 'mailgun',
  'manageengine-servicedesk-plus': 'manageengine_sdp',
  'mem0': 'mem0',
  'microsoft-dataverse': 'microsoft_dataverse',
  'microsoft-dynamics-365-crm': 'microsoft_dynamics_365',
  'microsoft-excel': 'microsoft_excel',
  'microsoft-intune': 'intune',
  'microsoft-planner': 'microsoft_planner',
  'microsoft-sql-server': 'mssql',
  'microsoft-teams': 'microsoft_teams',
  'microsoft-word': 'microsoft_word',
  'millionverifier': 'millionverifier',
  'mintlify': 'mintlify',
  'mistral-parser': 'mistral_parse',
  'modal': 'modal',
  'monday': 'monday',
  'mongodb': 'mongodb',
  'mysql': 'mysql',
  'neo4j': 'neo4j',
  'neverbounce': 'neverbounce',
  'new-relic': 'new_relic',
  'notion': 'notion',
  'obsidian': 'obsidian',
  'okta': 'okta',
  'onedrive': 'onedrive',
  'oracle-database': 'oracledb',
  'oracle-fusion-financials': 'oracle_fusion_financials',
  'oracle-netsuite': 'netsuite',
  'otter-ai': 'otter',
  'outlook': 'outlook',
  'pagerduty': 'pagerduty',
  'parallel-ai': 'parallel_ai',
  'people-data-labs': 'peopledatalabs',
  'perplexity': 'perplexity',
  'persona': 'persona',
  'pinecone': 'pinecone',
  'pipedrive': 'pipedrive',
  'pitchbook': 'pitchbook',
  'plane': 'plane',
  'planetscale': 'planetscale',
  'polymarket': 'polymarket',
  'postgresql': 'postgresql',
  'posthog': 'posthog',
  'power-bi': 'powerbi',
  'profound': 'profound',
  'prospeo': 'prospeo',
  'pulse': 'pulse',
  'qdrant': 'qdrant',
  'quartr': 'quartr',
  'quickbooks': 'quickbooks',
  'quiver': 'quiver',
  'rabbitmq': 'rabbitmq',
  'railway': 'railway',
  'ramp': 'ramp',
  'rb2b': 'rb2b',
  'reddit': 'reddit',
  'redis': 'redis',
  'reducto': 'reducto',
  'resend': 'resend',
  'revenuecat': 'revenuecat',
  'rippling': 'rippling',
  'rocketlane': 'rocketlane',
  'rootly': 'rootly',
  's3': 's3',
  'sailpoint': 'sailpoint',
  'salesforce': 'salesforce',
  'sap-concur': 'sap_concur',
  'sap-s4hana': 'sap_s4hana',
  'semrush': 'semrush',
  'sendblue': 'sendblue',
  'sendgrid': 'sendgrid',
  'sentry': 'sentry',
  'serper': 'serper',
  'servicenow': 'servicenow',
  'sftp': 'sftp',
  'sharepoint': 'sharepoint',
  'shopify': 'shopify',
  'similarweb': 'similarweb',
  'sixtyfour-ai': 'sixtyfour',
  'slack': 'slack',
  'smartlead': 'smartlead',
  'smtp': 'smtp',
  'snowflake': 'snowflake',
  'splunk': 'splunk',
  'sportmonks': 'sportmonks',
  'square': 'square',
  'ssh': 'ssh',
  'stagehand': 'stagehand',
  'stripe': 'stripe',
  'supabase': 'supabase',
  'tailscale': 'tailscale',
  'tavily': 'tavily',
  'telegram': 'telegram',
  'temporal': 'temporal',
  'thrive': 'thrive',
  'tiktok': 'tiktok',
  'tinybird': 'tinybird',
  'tinyfish': 'tinyfish',
  'trello': 'trello',
  'trigger-dev': 'trigger_dev',
  'twilio-sms': 'twilio_sms',
  'twilio-voice': 'twilio_voice',
  'typeform': 'typeform',
  'upstash': 'upstash',
  'uptimerobot': 'uptimerobot',
  'vanta': 'vanta',
  'vercel': 'vercel',
  'wealthbox': 'wealthbox',
  'webflow': 'webflow',
  'whatsapp': 'whatsapp',
  'wikipedia': 'wikipedia',
  'windchill': 'windchill',
  'wiza': 'wiza',
  'wordpress': 'wordpress',
  'workday': 'workday',
  'x': 'x',
  'you-com': 'youcom',
  'youtube': 'youtube',
  'zendesk': 'zendesk',
  'zep': 'zep',
  'zerobounce': 'zerobounce',
  'zoho-desk': 'zoho_desk',
  'zoom': 'zoom',
  'zoominfo': 'zoominfo',
};
