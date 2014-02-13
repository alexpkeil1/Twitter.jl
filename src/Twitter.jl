module Twitter

#############################################################
#
# Imports & Exports
#
#############################################################

using Codecs, HttpCommon, Requests, JSON, Nettle

#External files by API section
include("dm.jl")
include("favorites.jl")
include("friendsfollowers.jl")
include("geo.jl")
include("help.jl")
include("lists.jl")
include("oauth.jl")
include("savedsearches.jl")
include("search.jl")
include("spam.jl")
include("streaming.jl")
include("suggestedusers.jl")
include("timelines.jl")
include("trends.jl")
include("tweets.jl")
include("users.jl")

export twitterauth, 						#Authentication function
	   twittercred, 						#Authentication object
	   get_user_timeline,					#public API function
	   search_tweets,						#public API function
	   get_friends_ids,						#public API function
	   get_followers_ids,					#public API function
	   get_friends_list,					#public API function
	   get_followers_list,					#public API function
	   get_help_configuration,				#public API function
	   get_help_privacy,					#public API function
	   get_help_tos,						#public API function
	   get_application_rate_limit_status,	#public API function
	   get_help_languages,					#public API function
	   oauthheader, 						#Helper function
	   post_status_update,   				#public API function
	   mentions_timeline,					#public API function
	   home_timeline,						#public API function
	   retweets_of_me,						#public API function
	   get_direct_messages,					#public API function
	   get_direct_messages_sent,			#public API function
	   get_account_settings,				#public API function	
	   validate_credentials,				#public API function	
	   get_blocks_list,						#public API function
	   get_blocks_ids,						#public API function
	   get_users_search,					#public API function
	   get_users_contributees,				#public API function
       get_users_contributors,              #public API function
       get_profile_banner,                  #public API function
       get_user_suggestions_slug,           #public API function
       get_user_suggestions,                #public API function
       get_favorites_list,                  #public API function
       get_lists,                           #public API function
       get_lists_memberships,               #public API function
       get_saved_searches_list              #public API function


#############################################################
#
# Custom Types
#
#############################################################

#Type to hold Twitter API credentials
type TWCRED
    consumer_key::ASCIIString
    consumer_secret::ASCIIString
    auth_only_bearer_token::ASCIIString
    oauth_token::ASCIIString
    oauth_secret::ASCIIString
end

#Tweets response object
#Users response object


#############################################################
#
# General Functions
#
#############################################################

#Function that builds global variable to hold authentication keys
function twitterauth(consumer_key::ASCIIString, consumer_secret::ASCIIString; oauth_token::ASCIIString="", oauth_secret::ASCIIString="")
    #Create a global variable to hold return from this function
    global twittercred
    
    #Do application_only authentication
    #https://dev.twitter.com/docs/auth/application-only-auth
        
        #Build authentication string values
        concat_consumer = "$(encodeURI(consumer_key)):$(encodeURI(consumer_secret))"
        auth_header_value = base64(concat_consumer)
    
        #Call Twitter API to get bearer token
        response = post(URI("https://api.twitter.com/oauth2/token"),
                            "grant_type=client_credentials",
                            {"Authorization" => "Basic $auth_header_value",
                             "Content-Type" => "application/x-www-form-urlencoded;charset=UTF-8"})
        
    #If successful, convert data into Dict to get token, return TWCRED
        if response.status == 200
            response_dict = JSON.parse(response.data)
            
            #Per Twitter docs, validate token_type as "bearer"
            if response_dict["token_type"] == "bearer"
                return twittercred = TWCRED(consumer_key,
                                            consumer_secret,
                                            response_dict["access_token"],
                                            oauth_token,
                                            oauth_secret)
            else
                error("API returned success, but didn't return 'bearer' token type. Error unknown, try again.")
            end
        else
            error("Authentication failed. Please validate your consumer_key & consumer_secret and try again.")
        end
    
    #TODO: Figure out how to do OAuth authentication directly, rather than user putting in credentials directly
end

#Use this function to build the header for every OAuth call
function oauthheader(httpmethod::String, baseurl::String, options::Dict)                
    
    #Format non-parameter strings
    baseurl = encodeURI(baseurl)
    httpmethod = encodeURI(uppercase(httpmethod))
    oauth_consumer_secret = encodeURI(twittercred.consumer_secret)
    oauth_token_secret = encodeURI(twittercred.oauth_secret)
    
    #keys for parameter string
    options["oauth_consumer_key"] = encodeURI(twittercred.consumer_key)
    options["oauth_nonce"] = encodeURI(randstring(32)) #32 random alphanumeric characters
    options["oauth_signature_method"] = "HMAC-SHA1"
    options["oauth_timestamp"] = @sprintf("%.0f", time()) #timestamp in seconds
    options["oauth_token"] = encodeURI(twittercred.oauth_token)
    options["oauth_version"] = "1.0"
    
    #Get all available keys, sort them
    optionskeys = collect(keys(options))
    sort!(optionskeys)

    #parameter_string
    #Inspired by Requests.format_query_string
    query_str = ""
    for k in optionskeys
        v = options["$(k)"] #get value for ordered key
        query_str *= "$k=$v&"
    end
    query_str = chop(query_str) # remove the trailing &
    
    parameter_string = encodeURI(query_str) 
    
    #signature_base_string
    signature_base_string = "$(httpmethod)&$(baseurl)&$(parameter_string)"
    
    #Signing key
    signing_key = "$(oauth_consumer_secret)&$(oauth_token_secret)"
    
    #Calculate OAuth signature
    h = HMACState(SHA1, signing_key)
	update!(h, signature_base_string)
	oauth_sig = encodeURI(base64(digest!(h)))
    
    return "OAuth oauth_consumer_key=\"$(options["oauth_consumer_key"])\", oauth_nonce=\"$(options["oauth_nonce"])\", oauth_signature=\"$(oauth_sig)\", oauth_signature_method=\"$(options["oauth_signature_method"])\", oauth_timestamp=\"$(options["oauth_timestamp"])\", oauth_token=\"$(options["oauth_token"])\", oauth_version=\"$(options["oauth_version"])\""
    
end

end # module
