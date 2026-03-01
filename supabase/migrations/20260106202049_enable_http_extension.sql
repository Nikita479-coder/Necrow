/*
  # Enable HTTP Extension

  1. Changes
    - Enable http extension for making HTTP calls from PL/pgSQL
*/

CREATE EXTENSION IF NOT EXISTS http WITH SCHEMA extensions;
