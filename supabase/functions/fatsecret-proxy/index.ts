// Placeholder: the FatSecret proxy is not implemented and the app does not
// call it. It used to be the "Hello {name}" template, which echoed request
// input back; until a real proxy exists it only answers with a short error.
//
// When implementing it: require a signed-in user (verify the JWT), validate
// `query` with requireText(..., { max: LIMITS.search }), cap page sizes, add a
// fetch timeout and never forward upstream error bodies.

import "@supabase/functions-js/edge-runtime.d.ts";
import { errorResponse } from "../_shared/validate.ts";

Deno.serve((req) => {
  if (req.method !== "POST" && req.method !== "GET") {
    return errorResponse(405, "Method not allowed.");
  }
  return errorResponse(501, "Not available.");
});
