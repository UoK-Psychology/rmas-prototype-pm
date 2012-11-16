require 'savon'

class Proposal < ActiveRecord::Base

	include ActiveModel::Dirty

	before_create :assign_rmas_id
	after_save :rmas_event
	after_destroy :rmas_destroy

	before_save do
		@changed_fields = self.changed
	end

	def generate_rmas_id
		# generate a new rmas id
		"urn:rmas:kent:pmtool:#{SecureRandom.uuid}"
	end

	def assign_rmas_id
		self.rmas_id = generate_rmas_id()
		@new_rec = true
	end

	def rmas_event
		if @new_rec
			self.rmas_new
		else
			self.rmas_updated
		end
	end

	def rmas_new
		puts 'sending proposal_created message'

		# generate the message
		message = {
			:message_type => 'proposal_created',
			:entity => {
				:id => self.rmas_id,
				:title => self.title,
				:description => self.description
			}
		}

		send_message message

	end

	def rmas_updated
		
		puts 'sending proposal_updated message'

		message = {
			:message_type => 'proposal_updated',
			:entity => {
				:id => self.rmas_id
			}
		}

		unless @changed_fields.empty?
			@changed_fields.each do |field|
				message[:entity].store(field, self[field])
			end
			
			puts message

			send_message message
		end
	end

	def rmas_destroy
		puts 'sending proposal_deleted message'

		message = {
			:message_type => 'proposal_deleted',
			:entity => {
				:id => self.rmas_id
			}
		}

		send_message message
	end

	def send_message(message)

		client = Savon::Client.new do
			wsdl.document = 'http://localhost:7789/?wsdl'
		end

		message['message_id'] = generate_rmas_id()

    a_title = "does this work?"

    xml_message = "<?xml version='1.0' encoding='UTF-8'?> 
    <rmas>
    	<message-type>Proposal-created</message-type><!-- RMAS message type -->
    	<!-- CERIF payload -->
    	<CERIF
    		xmlns='urn:xmlns:org:eurocris:cerif-1.4-0' 
    		xsi:schemaLocation='urn:xmlns:org:eurocris:cerif-1.4-0http://www.eurocris.org/Uploads/Web%20pages/CERIF-1.4/CERIF_1.4_0.xsd' 
    		xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'
    		release='1.4'
    		date='2012-04-12'
    		sourceDatabase='pFact'> 
    		<!-- Base project entity -->
    		<cfProj>
    			<cfProjId>urn:rmas:0078:pfact:2.02:UUID</cfProjId> <!-- RMAS identifier --> 
    			<cfStartDate>2010-01-01</cfStartDate> <!-- Project start --> 
    			<cfEndDate>2012-07-31</cfEndDate> <!-- Project end --> 
    			<cfAcro>RMAS</cfAcro> <!-- Project acronym -->
    			<cfTitle
    				cfLangCode='EN'
    				cfTrans='o'>#{self.title}</cfTitle> <!-- Link entity (denoting project co-ordinator) -->
    			<cfProj_OrgUnit>
    				<cfOrgUnitId>orgunit-exeter-internal-id</cfOrgUnitId>
    				<cfClassId>c31d3380-1cfd-11e1-8bc2-0800200c9a66</cfClassId>
    				<cfClassSchemeId>6b2b7d25-3491-11e1-b86c-0800200c9a66</cfClassSchemeId>
    			  	<cfStartDate>2010-01-01T00:00:00</cfStartDate> <!-- Project start --> 
    			  	<cfEndDate>2012-07-31T00:00:00</cfEndDate> <!-- Project end -->
    			</cfProj_OrgUnit>

    			<cfProj_Pers><!-- Link entity (denoting project principal investigator -->
    				<cfPersId>1123456</cfPersId>
    				<cfClassId>b0e11470-1cfd-11e1-8bc2-0800200c9a66</cfClassId>
    				<cfClassSchemeId>94fefd50-1d00-11e1-8bc2-0800200c9a66</cfClassSchemeId>  
    				<cfStartDate>2010-01-01T00:00:00</cfStartDate> <!-- Project start --> 
    				<cfEndDate>2012-07-31T00:00:00</cfEndDate> <!-- Project end -->
    			</cfProj_Pers> 
    		</cfProj>

    		<cfOrgUnit><!-- Referenced organisation entity -->
    			<cfOrgUnitId>orgunit-exeter-internal-id</cfOrgUnitId>
    			<cfName cfLangCode='en_GB' cfTrans='o'>University of Exeter</cfName>
    		</cfOrgUnit>

    		<cfPers> <!-- Referenced person entity -->
    			<cfPersId>1123456</cfPersId> 
    			<cfGender>m</cfGender>
    			<cfPersName>
    				<cfFamilyNames>Marshall</cfFamilyNames>
    				<cfFirstNames>Jason</cfFirstNames> 
    			</cfPersName>
    		</cfPers>
    	</CERIF>
    </rmas>"
  
		message_json = ActiveSupport::JSON.encode(message)

		response = client.request :push_event do
			soap.body = { :event => xml_message }
		end

		unless response.success?
			puts response.soap_fault
		end
	end

end
