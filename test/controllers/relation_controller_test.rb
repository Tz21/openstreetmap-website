require "test_helper"
require "relation_controller"

class RelationControllerTest < ActionController::TestCase
  api_fixtures

  ##
  # test all routes which lead to this controller
  def test_routes
    assert_routing(
      { :path => "/api/0.6/relation/create", :method => :put },
      { :controller => "relation", :action => "create" }
    )
    assert_routing(
      { :path => "/api/0.6/relation/1/full", :method => :get },
      { :controller => "relation", :action => "full", :id => "1" }
    )
    assert_routing(
      { :path => "/api/0.6/relation/1", :method => :get },
      { :controller => "relation", :action => "read", :id => "1" }
    )
    assert_routing(
      { :path => "/api/0.6/relation/1", :method => :put },
      { :controller => "relation", :action => "update", :id => "1" }
    )
    assert_routing(
      { :path => "/api/0.6/relation/1", :method => :delete },
      { :controller => "relation", :action => "delete", :id => "1" }
    )
    assert_routing(
      { :path => "/api/0.6/relations", :method => :get },
      { :controller => "relation", :action => "relations" }
    )

    assert_routing(
      { :path => "/api/0.6/node/1/relations", :method => :get },
      { :controller => "relation", :action => "relations_for_node", :id => "1" }
    )
    assert_routing(
      { :path => "/api/0.6/way/1/relations", :method => :get },
      { :controller => "relation", :action => "relations_for_way", :id => "1" }
    )
    assert_routing(
      { :path => "/api/0.6/relation/1/relations", :method => :get },
      { :controller => "relation", :action => "relations_for_relation", :id => "1" }
    )
  end

  # -------------------------------------
  # Test reading relations.
  # -------------------------------------

  def test_read
    # check that a visible relation is returned properly
    get :read, :id => current_relations(:visible_relation).id
    assert_response :success

    # check that an invisible relation is not returned
    get :read, :id => current_relations(:invisible_relation).id
    assert_response :gone

    # check chat a non-existent relation is not returned
    get :read, :id => 0
    assert_response :not_found
  end

  ##
  # check that all relations containing a particular node, and no extra
  # relations, are returned from the relations_for_node call.
  def test_relations_for_node
    node = create(:node)
    # should include relations with that node as a member
    relation_with_node = create(:relation_member, :member => node).relation
    # should ignore relations without that node as a member
    _relation_without_node = create(:relation_member).relation
    # should ignore relations with the node involved indirectly, via a way
    way = create(:way_node, :node => node).way
    _relation_with_way = create(:relation_member, :member => way).relation
    # should ignore relations with the node involved indirectly, via a relation
    second_relation = create(:relation_member, :member => node).relation
    _super_relation = create(:relation_member, :member => second_relation).relation
    # should combine multiple relation_member references into just one relation entry
    create(:relation_member, :member => node, :relation => relation_with_node, :sequence_id => 2)
    # should not include deleted relations
    deleted_relation = create(:relation, :deleted)
    create(:relation_member, :member => node, :relation => deleted_relation)

    check_relations_for_element(:relations_for_node, "node",
                                node.id,
                                [relation_with_node, second_relation])
  end

  def test_relations_for_way
    way = create(:way)
    # should include relations with that way as a member
    relation_with_way = create(:relation_member, :member => way).relation
    # should ignore relations without that way as a member
    _relation_without_way = create(:relation_member).relation
    # should ignore relations with the way involved indirectly, via a relation
    second_relation = create(:relation_member, :member => way).relation
    _super_relation = create(:relation_member, :member => second_relation).relation
    # should combine multiple relation_member references into just one relation entry
    create(:relation_member, :member => way, :relation => relation_with_way, :sequence_id => 2)
    # should not include deleted relations
    deleted_relation = create(:relation, :deleted)
    create(:relation_member, :member => way, :relation => deleted_relation)

    check_relations_for_element(:relations_for_way, "way",
                                way.id,
                                [relation_with_way, second_relation])
  end

  def test_relations_for_relation
    relation = create(:relation)
    # should include relations with that relation as a member
    relation_with_relation = create(:relation_member, :member => relation).relation
    # should ignore any relation without that relation as a member
    _relation_without_relation = create(:relation_member).relation
    # should ignore relations with the relation involved indirectly, via a relation
    second_relation = create(:relation_member, :member => relation).relation
    _super_relation = create(:relation_member, :member => second_relation).relation
    # should combine multiple relation_member references into just one relation entry
    create(:relation_member, :member => relation, :relation => relation_with_relation, :sequence_id => 2)
    # should not include deleted relations
    deleted_relation = create(:relation, :deleted)
    create(:relation_member, :member => relation, :relation => deleted_relation)
    check_relations_for_element(:relations_for_relation, "relation",
                                relation.id,
                                [relation_with_relation, second_relation])
  end

  def check_relations_for_element(method, type, id, expected_relations)
    # check the "relations for relation" mode
    get method, :id => id
    assert_response :success

    # count one osm element
    assert_select "osm[version='#{API_VERSION}'][generator='OpenStreetMap server']", 1

    # we should have only the expected number of relations
    assert_select "osm>relation", expected_relations.size

    # and each of them should contain the element we originally searched for
    expected_relations.each do |relation|
      # The relation should appear once, but the element could appear multiple times
      assert_select "osm>relation[id='#{relation.id}']", 1
      assert_select "osm>relation[id='#{relation.id}']>member[type='#{type}'][ref='#{id}']"
    end
  end

  def test_full
    # check the "full" mode
    get :full, :id => 999999
    assert_response :not_found

    get :full, :id => current_relations(:invisible_relation).id
    assert_response :gone

    get :full, :id => current_relations(:visible_relation).id
    assert_response :success
    # FIXME: check whether this contains the stuff we want!
  end

  ##
  # test fetching multiple relations
  def test_relations
    # check error when no parameter provided
    get :relations
    assert_response :bad_request

    # check error when no parameter value provided
    get :relations, :relations => ""
    assert_response :bad_request

    # test a working call
    get :relations, :relations => "1,2,4,7"
    assert_response :success
    assert_select "osm" do
      assert_select "relation", :count => 4
      assert_select "relation[id='1'][visible='true']", :count => 1
      assert_select "relation[id='2'][visible='false']", :count => 1
      assert_select "relation[id='4'][visible='true']", :count => 1
      assert_select "relation[id='7'][visible='true']", :count => 1
    end

    # check error when a non-existent relation is included
    get :relations, :relations => "1,2,4,7,400"
    assert_response :not_found
  end

  # -------------------------------------
  # Test simple relation creation.
  # -------------------------------------

  def test_create
    private_user = create(:user, :data_public => false)
    private_changeset = create(:changeset, :user => private_user)
    user = create(:user)
    changeset = create(:changeset, :user => user)
    node = create(:node)
    way = create(:way_with_nodes, :nodes_count => 2)

    basic_authorization private_user.email, "test"

    # create an relation without members
    content "<osm><relation changeset='#{private_changeset.id}'><tag k='test' v='yes' /></relation></osm>"
    put :create
    # hope for forbidden, due to user
    assert_response :forbidden,
                    "relation upload should have failed with forbidden"

    ###
    # create an relation with a node as member
    # This time try with a role attribute in the relation
    content "<osm><relation changeset='#{private_changeset.id}'>" +
            "<member  ref='#{node.id}' type='node' role='some'/>" +
            "<tag k='test' v='yes' /></relation></osm>"
    put :create
    # hope for forbidden due to user
    assert_response :forbidden,
                    "relation upload did not return forbidden status"

    ###
    # create an relation with a node as member, this time test that we don't
    # need a role attribute to be included
    content "<osm><relation changeset='#{private_changeset.id}'>" +
            "<member  ref='#{node.id}' type='node'/>" + "<tag k='test' v='yes' /></relation></osm>"
    put :create
    # hope for forbidden due to user
    assert_response :forbidden,
                    "relation upload did not return forbidden status"

    ###
    # create an relation with a way and a node as members
    content "<osm><relation changeset='#{private_changeset.id}'>" +
            "<member type='node' ref='#{node.id}' role='some'/>" +
            "<member type='way' ref='#{way.id}' role='other'/>" +
            "<tag k='test' v='yes' /></relation></osm>"
    put :create
    # hope for forbidden, due to user
    assert_response :forbidden,
                    "relation upload did not return success status"

    ## Now try with the public user
    basic_authorization user.email, "test"

    # create an relation without members
    content "<osm><relation changeset='#{changeset.id}'><tag k='test' v='yes' /></relation></osm>"
    put :create
    # hope for success
    assert_response :success,
                    "relation upload did not return success status"
    # read id of created relation and search for it
    relationid = @response.body
    checkrelation = Relation.find(relationid)
    assert_not_nil checkrelation,
                   "uploaded relation not found in data base after upload"
    # compare values
    assert_equal checkrelation.members.length, 0,
                 "saved relation contains members but should not"
    assert_equal checkrelation.tags.length, 1,
                 "saved relation does not contain exactly one tag"
    assert_equal changeset.id, checkrelation.changeset.id,
                 "saved relation does not belong in the changeset it was assigned to"
    assert_equal user.id, checkrelation.changeset.user_id,
                 "saved relation does not belong to user that created it"
    assert_equal true, checkrelation.visible,
                 "saved relation is not visible"
    # ok the relation is there but can we also retrieve it?
    get :read, :id => relationid
    assert_response :success

    ###
    # create an relation with a node as member
    # This time try with a role attribute in the relation
    content "<osm><relation changeset='#{changeset.id}'>" +
            "<member  ref='#{node.id}' type='node' role='some'/>" +
            "<tag k='test' v='yes' /></relation></osm>"
    put :create
    # hope for success
    assert_response :success,
                    "relation upload did not return success status"
    # read id of created relation and search for it
    relationid = @response.body
    checkrelation = Relation.find(relationid)
    assert_not_nil checkrelation,
                   "uploaded relation not found in data base after upload"
    # compare values
    assert_equal checkrelation.members.length, 1,
                 "saved relation does not contain exactly one member"
    assert_equal checkrelation.tags.length, 1,
                 "saved relation does not contain exactly one tag"
    assert_equal changeset.id, checkrelation.changeset.id,
                 "saved relation does not belong in the changeset it was assigned to"
    assert_equal user.id, checkrelation.changeset.user_id,
                 "saved relation does not belong to user that created it"
    assert_equal true, checkrelation.visible,
                 "saved relation is not visible"
    # ok the relation is there but can we also retrieve it?

    get :read, :id => relationid
    assert_response :success

    ###
    # create an relation with a node as member, this time test that we don't
    # need a role attribute to be included
    content "<osm><relation changeset='#{changeset.id}'>" +
            "<member  ref='#{node.id}' type='node'/>" + "<tag k='test' v='yes' /></relation></osm>"
    put :create
    # hope for success
    assert_response :success,
                    "relation upload did not return success status"
    # read id of created relation and search for it
    relationid = @response.body
    checkrelation = Relation.find(relationid)
    assert_not_nil checkrelation,
                   "uploaded relation not found in data base after upload"
    # compare values
    assert_equal checkrelation.members.length, 1,
                 "saved relation does not contain exactly one member"
    assert_equal checkrelation.tags.length, 1,
                 "saved relation does not contain exactly one tag"
    assert_equal changeset.id, checkrelation.changeset.id,
                 "saved relation does not belong in the changeset it was assigned to"
    assert_equal user.id, checkrelation.changeset.user_id,
                 "saved relation does not belong to user that created it"
    assert_equal true, checkrelation.visible,
                 "saved relation is not visible"
    # ok the relation is there but can we also retrieve it?

    get :read, :id => relationid
    assert_response :success

    ###
    # create an relation with a way and a node as members
    content "<osm><relation changeset='#{changeset.id}'>" +
            "<member type='node' ref='#{node.id}' role='some'/>" +
            "<member type='way' ref='#{way.id}' role='other'/>" +
            "<tag k='test' v='yes' /></relation></osm>"
    put :create
    # hope for success
    assert_response :success,
                    "relation upload did not return success status"
    # read id of created relation and search for it
    relationid = @response.body
    checkrelation = Relation.find(relationid)
    assert_not_nil checkrelation,
                   "uploaded relation not found in data base after upload"
    # compare values
    assert_equal checkrelation.members.length, 2,
                 "saved relation does not have exactly two members"
    assert_equal checkrelation.tags.length, 1,
                 "saved relation does not contain exactly one tag"
    assert_equal changeset.id, checkrelation.changeset.id,
                 "saved relation does not belong in the changeset it was assigned to"
    assert_equal user.id, checkrelation.changeset.user_id,
                 "saved relation does not belong to user that created it"
    assert_equal true, checkrelation.visible,
                 "saved relation is not visible"
    # ok the relation is there but can we also retrieve it?
    get :read, :id => relationid
    assert_response :success
  end

  # ------------------------------------
  # Test updating relations
  # ------------------------------------

  ##
  # test that, when tags are updated on a relation, the correct things
  # happen to the correct tables and the API gives sensible results.
  # this is to test a case that gregory marler noticed and posted to
  # josm-dev.
  ## FIXME Move this to an integration test
  def test_update_relation_tags
    user = create(:user)
    changeset = create(:changeset, :user => user)
    relation = create(:relation)
    create_list(:relation_tag, 4, :relation => relation)

    basic_authorization user.email, "test"

    with_relation(relation.id) do |rel|
      # alter one of the tags
      tag = rel.find("//osm/relation/tag").first
      tag["v"] = "some changed value"
      update_changeset(rel, changeset.id)

      # check that the downloaded tags are the same as the uploaded tags...
      new_version = with_update(rel) do |new_rel|
        assert_tags_equal rel, new_rel
      end

      # check the original one in the current_* table again
      with_relation(relation.id) { |r| assert_tags_equal rel, r }

      # now check the version in the history
      with_relation(relation.id, new_version) { |r| assert_tags_equal rel, r }
    end
  end

  ##
  # test that, when tags are updated on a relation when using the diff
  # upload function, the correct things happen to the correct tables
  # and the API gives sensible results. this is to test a case that
  # gregory marler noticed and posted to josm-dev.
  def test_update_relation_tags_via_upload
    user = create(:user)
    changeset = create(:changeset, :user => user)
    relation = create(:relation)
    create_list(:relation_tag, 4, :relation => relation)

    basic_authorization user.email, "test"

    with_relation(relation.id) do |rel|
      # alter one of the tags
      tag = rel.find("//osm/relation/tag").first
      tag["v"] = "some changed value"
      update_changeset(rel, changeset.id)

      # check that the downloaded tags are the same as the uploaded tags...
      new_version = with_update_diff(rel) do |new_rel|
        assert_tags_equal rel, new_rel
      end

      # check the original one in the current_* table again
      with_relation(relation.id) { |r| assert_tags_equal rel, r }

      # now check the version in the history
      with_relation(relation.id, new_version) { |r| assert_tags_equal rel, r }
    end
  end

  def test_update_wrong_id
    user = create(:user)
    changeset = create(:changeset, :user => user)
    relation = create(:relation)
    other_relation = create(:relation)

    basic_authorization user.email, "test"
    with_relation(relation.id) do |rel|
      update_changeset(rel, changeset.id)
      content rel
      put :update, :id => other_relation.id
      assert_response :bad_request
    end
  end

  # -------------------------------------
  # Test creating some invalid relations.
  # -------------------------------------

  def test_create_invalid
    user = create(:user)
    changeset = create(:changeset, :user => user)

    basic_authorization user.email, "test"

    # create a relation with non-existing node as member
    content "<osm><relation changeset='#{changeset.id}'>" +
            "<member type='node' ref='0'/><tag k='test' v='yes' />" +
            "</relation></osm>"
    put :create
    # expect failure
    assert_response :precondition_failed,
                    "relation upload with invalid node did not return 'precondition failed'"
    assert_equal "Precondition failed: Relation with id  cannot be saved due to Node with id 0", @response.body
  end

  # -------------------------------------
  # Test creating a relation, with some invalid XML
  # -------------------------------------
  def test_create_invalid_xml
    user = create(:user)
    changeset = create(:changeset, :user => user)
    node = create(:node)

    basic_authorization user.email, "test"

    # create some xml that should return an error
    content "<osm><relation changeset='#{changeset.id}'>" +
            "<member type='type' ref='#{node.id}' role=''/>" +
            "<tag k='tester' v='yep'/></relation></osm>"
    put :create
    # expect failure
    assert_response :bad_request
    assert_match(/Cannot parse valid relation from xml string/, @response.body)
    assert_match(/The type is not allowed only, /, @response.body)
  end

  # -------------------------------------
  # Test deleting relations.
  # -------------------------------------

  def test_delete
    private_user = create(:user, :data_public => false)
    private_user_closed_changeset = create(:changeset, :closed, :user => private_user)
    user = create(:user)
    closed_changeset = create(:changeset, :closed, :user => user)
    changeset = create(:changeset, :user => user)
    relation = create(:relation)
    used_relation = create(:relation)
    super_relation = create(:relation_member, :member => used_relation).relation
    deleted_relation = create(:relation, :deleted)
    multi_tag_relation = create(:relation)
    create_list(:relation_tag, 4, :relation => multi_tag_relation)

    ## First try to delete relation without auth
    delete :delete, :id => relation.id
    assert_response :unauthorized

    ## Then try with the private user, to make sure that you get a forbidden
    basic_authorization(private_user.email, "test")

    # this shouldn't work, as we should need the payload...
    delete :delete, :id => relation.id
    assert_response :forbidden

    # try to delete without specifying a changeset
    content "<osm><relation id='#{relation.id}'/></osm>"
    delete :delete, :id => relation.id
    assert_response :forbidden

    # try to delete with an invalid (closed) changeset
    content update_changeset(relation.to_xml,
                             private_user_closed_changeset.id)
    delete :delete, :id => relation.id
    assert_response :forbidden

    # try to delete with an invalid (non-existent) changeset
    content update_changeset(relation.to_xml, 0)
    delete :delete, :id => relation.id
    assert_response :forbidden

    # this won't work because the relation is in-use by another relation
    content(used_relation.to_xml)
    delete :delete, :id => used_relation.id
    assert_response :forbidden

    # this should work when we provide the appropriate payload...
    content(relation.to_xml)
    delete :delete, :id => relation.id
    assert_response :forbidden

    # this won't work since the relation is already deleted
    content(deleted_relation.to_xml)
    delete :delete, :id => deleted_relation.id
    assert_response :forbidden

    # this won't work since the relation never existed
    delete :delete, :id => 0
    assert_response :forbidden

    ## now set auth for the public user
    basic_authorization(user.email, "test")

    # this shouldn't work, as we should need the payload...
    delete :delete, :id => relation.id
    assert_response :bad_request

    # try to delete without specifying a changeset
    content "<osm><relation id='#{relation.id}' version='#{relation.version}' /></osm>"
    delete :delete, :id => relation.id
    assert_response :bad_request
    assert_match(/Changeset id is missing/, @response.body)

    # try to delete with an invalid (closed) changeset
    content update_changeset(relation.to_xml,
                             closed_changeset.id)
    delete :delete, :id => relation.id
    assert_response :conflict

    # try to delete with an invalid (non-existent) changeset
    content update_changeset(relation.to_xml, 0)
    delete :delete, :id => relation.id
    assert_response :conflict

    # this won't work because the relation is in a changeset owned by someone else
    content update_changeset(relation.to_xml, create(:changeset).id)
    delete :delete, :id => relation.id
    assert_response :conflict,
                    "shouldn't be able to delete a relation in a changeset owned by someone else (#{@response.body})"

    # this won't work because the relation in the payload is different to that passed
    content update_changeset(relation.to_xml, changeset.id)
    delete :delete, :id => create(:relation).id
    assert_response :bad_request, "shouldn't be able to delete a relation when payload is different to the url"

    # this won't work because the relation is in-use by another relation
    content update_changeset(used_relation.to_xml, changeset.id)
    delete :delete, :id => used_relation.id
    assert_response :precondition_failed,
                    "shouldn't be able to delete a relation used in a relation (#{@response.body})"
    assert_equal "Precondition failed: The relation #{used_relation.id} is used in relation #{super_relation.id}.", @response.body

    # this should work when we provide the appropriate payload...
    content update_changeset(multi_tag_relation.to_xml, changeset.id)
    delete :delete, :id => multi_tag_relation.id
    assert_response :success

    # valid delete should return the new version number, which should
    # be greater than the old version number
    assert @response.body.to_i > multi_tag_relation.version,
           "delete request should return a new version number for relation"

    # this won't work since the relation is already deleted
    content update_changeset(deleted_relation.to_xml, changeset.id)
    delete :delete, :id => deleted_relation.id
    assert_response :gone

    # Public visible relation needs to be deleted
    content update_changeset(super_relation.to_xml, changeset.id)
    delete :delete, :id => super_relation.id
    assert_response :success

    # this works now because the relation which was using this one
    # has been deleted.
    content update_changeset(used_relation.to_xml, changeset.id)
    delete :delete, :id => used_relation.id
    assert_response :success,
                    "should be able to delete a relation used in an old relation (#{@response.body})"

    # this won't work since the relation never existed
    delete :delete, :id => 0
    assert_response :not_found
  end

  ##
  # when a relation's tag is modified then it should put the bounding
  # box of all its members into the changeset.
  def test_tag_modify_bounding_box
    # in current fixtures, relation 5 contains nodes 3 and 5 (node 3
    # indirectly via way 3), so the bbox should be [3,3,5,5].
    check_changeset_modify(BoundingBox.new(3, 3, 5, 5)) do |changeset_id|
      # add a tag to an existing relation
      relation_xml = current_relations(:visible_relation).to_xml
      relation_element = relation_xml.find("//osm/relation").first
      new_tag = XML::Node.new("tag")
      new_tag["k"] = "some_new_tag"
      new_tag["v"] = "some_new_value"
      relation_element << new_tag

      # update changeset ID to point to new changeset
      update_changeset(relation_xml, changeset_id)

      # upload the change
      content relation_xml
      put :update, :id => current_relations(:visible_relation).id
      assert_response :success, "can't update relation for tag/bbox test"
    end
  end

  ##
  # add a member to a relation and check the bounding box is only that
  # element.
  def test_add_member_bounding_box
    relation_id = current_relations(:visible_relation).id

    [current_nodes(:used_node_1),
     current_nodes(:used_node_2),
     current_ways(:used_way),
     current_ways(:way_with_versions)].each_with_index do |element, _version|
      bbox = element.bbox.to_unscaled
      check_changeset_modify(bbox) do |changeset_id|
        relation_xml = Relation.find(relation_id).to_xml
        relation_element = relation_xml.find("//osm/relation").first
        new_member = XML::Node.new("member")
        new_member["ref"] = element.id.to_s
        new_member["type"] = element.class.to_s.downcase
        new_member["role"] = "some_role"
        relation_element << new_member

        # update changeset ID to point to new changeset
        update_changeset(relation_xml, changeset_id)

        # upload the change
        content relation_xml
        put :update, :id => current_relations(:visible_relation).id
        assert_response :success, "can't update relation for add #{element.class}/bbox test: #{@response.body}"

        # get it back and check the ordering
        get :read, :id => relation_id
        assert_response :success, "can't read back the relation: #{@response.body}"
        check_ordering(relation_xml, @response.body)
      end
    end
  end

  ##
  # remove a member from a relation and check the bounding box is
  # only that element.
  def test_remove_member_bounding_box
    check_changeset_modify(BoundingBox.new(5, 5, 5, 5)) do |changeset_id|
      # remove node 5 (5,5) from an existing relation
      relation_xml = current_relations(:visible_relation).to_xml
      relation_xml
        .find("//osm/relation/member[@type='node'][@ref='5']")
        .first.remove!

      # update changeset ID to point to new changeset
      update_changeset(relation_xml, changeset_id)

      # upload the change
      content relation_xml
      put :update, :id => current_relations(:visible_relation).id
      assert_response :success, "can't update relation for remove node/bbox test"
    end
  end

  ##
  # check that relations are ordered
  def test_relation_member_ordering
    user = create(:user)
    changeset = create(:changeset, :user => user)
    node1 = create(:node)
    node2 = create(:node)
    node3 = create(:node)
    way1 = create(:way_with_nodes, :nodes_count => 2)
    way2 = create(:way_with_nodes, :nodes_count => 2)

    basic_authorization(user.email, "test")

    doc_str = <<OSM
<osm>
 <relation changeset='#{changeset.id}'>
  <member ref='#{node1.id}' type='node' role='first'/>
  <member ref='#{node2.id}' type='node' role='second'/>
  <member ref='#{way1.id}' type='way' role='third'/>
  <member ref='#{way2.id}' type='way' role='fourth'/>
 </relation>
</osm>
OSM
    doc = XML::Parser.string(doc_str).parse

    content doc
    put :create
    assert_response :success, "can't create a relation: #{@response.body}"
    relation_id = @response.body.to_i

    # get it back and check the ordering
    get :read, :id => relation_id
    assert_response :success, "can't read back the relation: #{@response.body}"
    check_ordering(doc, @response.body)

    # insert a member at the front
    new_member = XML::Node.new "member"
    new_member["ref"] = node3.id.to_s
    new_member["type"] = "node"
    new_member["role"] = "new first"
    doc.find("//osm/relation").first.child.prev = new_member
    # update the version, should be 1?
    doc.find("//osm/relation").first["id"] = relation_id.to_s
    doc.find("//osm/relation").first["version"] = 1.to_s

    # upload the next version of the relation
    content doc
    put :update, :id => relation_id
    assert_response :success, "can't update relation: #{@response.body}"
    assert_equal 2, @response.body.to_i

    # get it back again and check the ordering again
    get :read, :id => relation_id
    assert_response :success, "can't read back the relation: #{@response.body}"
    check_ordering(doc, @response.body)

    # check the ordering in the history tables:
    with_controller(OldRelationController.new) do
      get :version, :id => relation_id, :version => 2
      assert_response :success, "can't read back version 2 of the relation #{relation_id}"
      check_ordering(doc, @response.body)
    end
  end

  ##
  # check that relations can contain duplicate members
  def test_relation_member_duplicates
    private_user = create(:user, :data_public => false)
    user = create(:user)
    changeset = create(:changeset, :user => user)
    node1 = create(:node)
    node2 = create(:node)

    doc_str = <<OSM
<osm>
 <relation changeset='#{changeset.id}'>
  <member ref='#{node1.id}' type='node' role='forward'/>
  <member ref='#{node2.id}' type='node' role='forward'/>
  <member ref='#{node1.id}' type='node' role='forward'/>
  <member ref='#{node2.id}' type='node' role='forward'/>
 </relation>
</osm>
OSM
    doc = XML::Parser.string(doc_str).parse

    ## First try with the private user
    basic_authorization(private_user.email, "test")

    content doc
    put :create
    assert_response :forbidden

    ## Now try with the public user
    basic_authorization(user.email, "test")

    content doc
    put :create
    assert_response :success, "can't create a relation: #{@response.body}"
    relation_id = @response.body.to_i

    # get it back and check the ordering
    get :read, :id => relation_id
    assert_response :success, "can't read back the relation: #{relation_id}"
    check_ordering(doc, @response.body)
  end

  ##
  # test that the ordering of elements in the history is the same as in current.
  def test_history_ordering
    user = create(:user)
    changeset = create(:changeset, :user => user)
    node1 = create(:node)
    node2 = create(:node)
    node3 = create(:node)
    node4 = create(:node)

    doc_str = <<OSM
<osm>
 <relation changeset='#{changeset.id}'>
  <member ref='#{node1.id}' type='node' role='forward'/>
  <member ref='#{node4.id}' type='node' role='forward'/>
  <member ref='#{node3.id}' type='node' role='forward'/>
  <member ref='#{node2.id}' type='node' role='forward'/>
 </relation>
</osm>
OSM
    doc = XML::Parser.string(doc_str).parse
    basic_authorization(user.email, "test")

    content doc
    put :create
    assert_response :success, "can't create a relation: #{@response.body}"
    relation_id = @response.body.to_i

    # check the ordering in the current tables:
    get :read, :id => relation_id
    assert_response :success, "can't read back the relation: #{@response.body}"
    check_ordering(doc, @response.body)

    # check the ordering in the history tables:
    with_controller(OldRelationController.new) do
      get :version, :id => relation_id, :version => 1
      assert_response :success, "can't read back version 1 of the relation: #{@response.body}"
      check_ordering(doc, @response.body)
    end
  end

  ##
  # remove all the members from a relation. the result is pretty useless, but
  # still technically valid.
  def test_remove_all_members
    check_changeset_modify(BoundingBox.new(3, 3, 5, 5)) do |changeset_id|
      relation_xml = current_relations(:visible_relation).to_xml
      relation_xml
        .find("//osm/relation/member")
        .each(&:remove!)

      # update changeset ID to point to new changeset
      update_changeset(relation_xml, changeset_id)

      # upload the change
      content relation_xml
      put :update, :id => current_relations(:visible_relation).id
      assert_response :success, "can't update relation for remove all members test"
      checkrelation = Relation.find(current_relations(:visible_relation).id)
      assert_not_nil(checkrelation,
                     "uploaded relation not found in database after upload")
      assert_equal(0, checkrelation.members.length,
                   "relation contains members but they should have all been deleted")
    end
  end

  # ============================================================
  # utility functions
  # ============================================================

  ##
  # checks that the XML document and the string arguments have
  # members in the same order.
  def check_ordering(doc, xml)
    new_doc = XML::Parser.string(xml).parse

    doc_members = doc.find("//osm/relation/member").collect do |m|
      [m["ref"].to_i, m["type"].to_sym, m["role"]]
    end

    new_members = new_doc.find("//osm/relation/member").collect do |m|
      [m["ref"].to_i, m["type"].to_sym, m["role"]]
    end

    doc_members.zip(new_members).each do |d, n|
      assert_equal d, n, "members are not equal - ordering is wrong? (#{doc}, #{xml})"
    end
  end

  ##
  # create a changeset and yield to the caller to set it up, then assert
  # that the changeset bounding box is +bbox+.
  def check_changeset_modify(bbox)
    ## First test with the private user to check that you get a forbidden
    basic_authorization(users(:normal_user).email, "test")

    # create a new changeset for this operation, so we are assured
    # that the bounding box will be newly-generated.
    changeset_id = with_controller(ChangesetController.new) do
      content "<osm><changeset/></osm>"
      put :create
      assert_response :forbidden, "shouldn't be able to create changeset for modify test, as should get forbidden"
    end

    ## Now do the whole thing with the public user
    basic_authorization(users(:public_user).email, "test")

    # create a new changeset for this operation, so we are assured
    # that the bounding box will be newly-generated.
    changeset_id = with_controller(ChangesetController.new) do
      content "<osm><changeset/></osm>"
      put :create
      assert_response :success, "couldn't create changeset for modify test"
      @response.body.to_i
    end

    # go back to the block to do the actual modifies
    yield changeset_id

    # now download the changeset to check its bounding box
    with_controller(ChangesetController.new) do
      get :read, :id => changeset_id
      assert_response :success, "can't re-read changeset for modify test"
      assert_select "osm>changeset", 1, "Changeset element doesn't exist in #{@response.body}"
      assert_select "osm>changeset[id='#{changeset_id}']", 1, "Changeset id=#{changeset_id} doesn't exist in #{@response.body}"
      assert_select "osm>changeset[min_lon='#{bbox.min_lon}']", 1, "Changeset min_lon wrong in #{@response.body}"
      assert_select "osm>changeset[min_lat='#{bbox.min_lat}']", 1, "Changeset min_lat wrong in #{@response.body}"
      assert_select "osm>changeset[max_lon='#{bbox.max_lon}']", 1, "Changeset max_lon wrong in #{@response.body}"
      assert_select "osm>changeset[max_lat='#{bbox.max_lat}']", 1, "Changeset max_lat wrong in #{@response.body}"
    end
  end

  ##
  # yields the relation with the given +id+ (and optional +version+
  # to read from the history tables) into the block. the parsed XML
  # doc is returned.
  def with_relation(id, ver = nil)
    if ver.nil?
      get :read, :id => id
    else
      with_controller(OldRelationController.new) do
        get :version, :id => id, :version => ver
      end
    end
    assert_response :success
    yield xml_parse(@response.body)
  end

  ##
  # updates the relation (XML) +rel+ and
  # yields the new version of that relation into the block.
  # the parsed XML doc is retured.
  def with_update(rel)
    rel_id = rel.find("//osm/relation").first["id"].to_i
    content rel
    put :update, :id => rel_id
    assert_response :success, "can't update relation: #{@response.body}"
    version = @response.body.to_i

    # now get the new version
    get :read, :id => rel_id
    assert_response :success
    new_rel = xml_parse(@response.body)

    yield new_rel

    version
  end

  ##
  # updates the relation (XML) +rel+ via the diff-upload API and
  # yields the new version of that relation into the block.
  # the parsed XML doc is retured.
  def with_update_diff(rel)
    rel_id = rel.find("//osm/relation").first["id"].to_i
    cs_id = rel.find("//osm/relation").first["changeset"].to_i
    version = nil

    with_controller(ChangesetController.new) do
      doc = OSM::API.new.get_xml_doc
      change = XML::Node.new "osmChange"
      doc.root = change
      modify = XML::Node.new "modify"
      change << modify
      modify << doc.import(rel.find("//osm/relation").first)

      content doc.to_s
      post :upload, :id => cs_id
      assert_response :success, "can't upload diff relation: #{@response.body}"
      version = xml_parse(@response.body).find("//diffResult/relation").first["new_version"].to_i
    end

    # now get the new version
    get :read, :id => rel_id
    assert_response :success
    new_rel = xml_parse(@response.body)

    yield new_rel

    version
  end

  ##
  # returns a k->v hash of tags from an xml doc
  def get_tags_as_hash(a)
    a.find("//osm/relation/tag").sort_by { |v| v["k"] }.each_with_object({}) do |v, h|
      h[v["k"]] = v["v"]
    end
  end

  ##
  # assert that all tags on relation documents +a+ and +b+
  # are equal
  def assert_tags_equal(a, b)
    # turn the XML doc into tags hashes
    a_tags = get_tags_as_hash(a)
    b_tags = get_tags_as_hash(b)

    assert_equal a_tags.keys, b_tags.keys, "Tag keys should be identical."
    a_tags.each do |k, v|
      assert_equal v, b_tags[k],
                   "Tags which were not altered should be the same. " +
                   "#{a_tags.inspect} != #{b_tags.inspect}"
    end
  end

  ##
  # update the changeset_id of a node element
  def update_changeset(xml, changeset_id)
    xml_attr_rewrite(xml, "changeset", changeset_id)
  end

  ##
  # update an attribute in the node element
  def xml_attr_rewrite(xml, name, value)
    xml.find("//osm/relation").first[name] = value.to_s
    xml
  end

  ##
  # parse some xml
  def xml_parse(xml)
    parser = XML::Parser.string(xml)
    parser.parse
  end
end
