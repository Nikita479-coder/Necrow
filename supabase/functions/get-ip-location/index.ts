import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

interface IpLocationResponse {
  ip: string;
  city?: string;
  region?: string;
  country?: string;
  country_code?: string;
  timezone?: string;
  latitude?: number;
  longitude?: number;
  isp?: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 200,
      headers: corsHeaders,
    });
  }

  try {
    let clientIp = '';
    
    // Try to get IP from various headers
    const forwardedFor = req.headers.get('x-forwarded-for');
    const realIp = req.headers.get('x-real-ip');
    const cfConnectingIp = req.headers.get('cf-connecting-ip');
    
    if (cfConnectingIp) {
      clientIp = cfConnectingIp;
    } else if (forwardedFor) {
      // x-forwarded-for can contain multiple IPs, get the first one
      clientIp = forwardedFor.split(',')[0].trim();
    } else if (realIp) {
      clientIp = realIp;
    }

    // If request body contains an IP, use that (for testing)
    if (req.method === 'POST') {
      try {
        const body = await req.json();
        if (body.ip) {
          clientIp = body.ip;
        }
      } catch {
        // Ignore JSON parse errors for GET-style requests
      }
    }

    // If no IP found, try to detect from external service
    if (!clientIp) {
      try {
        const ipResponse = await fetch('https://api.ipify.org?format=json');
        const ipData = await ipResponse.json();
        clientIp = ipData.ip || 'unknown';
      } catch {
        clientIp = 'unknown';
      }
    }

    // Get location data from ipapi.co (free tier: 1000 requests/day)
    let locationData: IpLocationResponse = { ip: clientIp };
    
    if (clientIp && clientIp !== 'unknown' && !clientIp.startsWith('127.') && !clientIp.startsWith('192.168.') && !clientIp.startsWith('10.')) {
      try {
        const geoResponse = await fetch(`https://ipapi.co/${clientIp}/json/`);
        if (geoResponse.ok) {
          const geoData = await geoResponse.json();
          locationData = {
            ip: clientIp,
            city: geoData.city,
            region: geoData.region,
            country: geoData.country_name,
            country_code: geoData.country_code,
            timezone: geoData.timezone,
            latitude: geoData.latitude,
            longitude: geoData.longitude,
            isp: geoData.org,
          };
        }
      } catch (geoError) {
        console.error('Error fetching geolocation:', geoError);
        // Return IP only if geolocation fails
      }
    }

    return new Response(
      JSON.stringify(locationData),
      {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  } catch (error: any) {
    console.error('Error in get-ip-location:', error);
    
    return new Response(
      JSON.stringify({
        error: error.message || 'Failed to get IP location',
        ip: 'unknown',
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  }
});